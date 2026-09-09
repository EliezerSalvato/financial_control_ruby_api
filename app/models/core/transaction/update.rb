class Core::Transaction::Update < ApplicationSolidProcess
  SCHEDULE_FIELDS = %i[
    kind payment_method recurrence_type starts_on value limit_consumption_type
  ].freeze
  PAYMENT_TARGET_FIELDS = %i[
    account_id credit_card_id source_account_id destination_account_id
  ].freeze

  deps do
    attribute :transaction_repository, default: -> { Transaction::Adapters.repository }
    attribute :tagging_repository, default: -> { Transaction::Adapters.tagging_repository }
    attribute :category_repository, default: -> { Category::Adapters.repository }
    attribute :tag_repository, default: -> { Tag::Adapters.repository }

    validates :transaction_repository, kind_of: Core::Transaction::Repository::Interface
    validates :tagging_repository, kind_of: Core::Transaction::Tagging::Repository::Interface
    validates :category_repository, kind_of: Core::Category::Repository::Interface
    validates :tag_repository, kind_of: Core::Tag::Repository::Interface
  end

  input do
    attribute :user
    attribute :id, :string
    attribute :category_id, :string
    attribute :description, :string
    attribute :kind, :string
    attribute :payment_method, :string
    attribute :recurrence_type, :string
    attribute :ends_on, :date
    attribute :starts_on, :date
    attribute :value, :decimal
    attribute :limit_consumption_type, :string
    attribute :account_id, :string
    attribute :credit_card_id, :string
    attribute :source_account_id, :string
    attribute :destination_account_id, :string
    attribute :tag_ids

    normalizes :description, with: ->(value) { value&.strip }
    normalizes :kind, :payment_method, :recurrence_type, :limit_consumption_type, with: ->(value) { value&.strip.presence }
    normalizes :category_id, :account_id, :credit_card_id, :source_account_id, :destination_account_id, with: ->(value) { value&.strip.presence }
    normalizes :tag_ids, with: ->(value) { value.to_a.map { |id| id.to_s.strip.presence }.compact.uniq }

    validates :user, :id, presence: true
    validates :user, kind_of: Core::User::Entity
    validates :description, presence: true, allow_nil: true
    validates :category_id, presence: true, allow_nil: true
    validates :kind, inclusion: { in: Core::Transaction::Kind::ALL }, allow_nil: true
    validates :payment_method, inclusion: { in: Core::Transaction::PaymentMethod::ALL }, allow_nil: true
    validates :recurrence_type, inclusion: { in: Core::Transaction::RecurrenceType::ALL }, allow_nil: true
    validates :value, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
    validates :limit_consumption_type, inclusion: { in: Core::Transaction::LimitConsumptionType::ALL }, allow_nil: true
  end

  def call(attributes)
    rollback_on_failure {
      Given(attributes)
        .and_then(:find_transaction)
        .and_then(:reject_not_allowed_fields_by_status)
        .and_then(:resolve_effective_attributes)
        .and_then(:calculate_installments_count)
        .and_then(:validate_payment_method_compatibility)
        .and_then(:ensure_invoice_unpaid)
        .and_then(:ensure_category_belongs_to_user)
        .and_then(:ensure_tags_belong_to_user)
        .and_then(:update_for_account)
        .and_then(:update_for_credit_card)
        .and_then(:update_for_transfer_between_accounts)
        .and_then(:update_recurrence)
        .and_then(:update_transaction)
        .and_then(:replace_taggings)
        .and_then(:reload_transaction)
    }
  end

  private

  def find_transaction(user:, id:, **)
    case deps.transaction_repository.find_by_id(user:, id:)
    in Solid::Success(transaction:) then Continue(transaction:)
    in Solid::Failure(type: :transaction_not_found)
      Failure(:transaction_not_found)
    end
  end

  def reject_not_allowed_fields_by_status(transaction:, **attributes)
    if transaction.completed_or_canceled?
      reject_provided_fields(attributes, SCHEDULE_FIELDS + PAYMENT_TARGET_FIELDS + [ :ends_on ])
    elsif transaction.active?
      reject_provided_fields(attributes, SCHEDULE_FIELDS)

      input.errors.add(:ends_on, :cannot_be_changed) if attributes[:ends_on].present? && transaction.recurrence_type != Core::Transaction::RecurrenceType::RECURRING
    end

    return Failure(:invalid_input, input:) if input.errors.any?

    Continue()
  end

  def resolve_effective_attributes(transaction:, kind:, payment_method:, recurrence_type:, ends_on:, **)
    effective_kind = kind.presence || transaction.kind
    effective_recurrence_type = recurrence_type.presence || transaction.recurrence_type
    effective_payment_method = if effective_kind == Core::Transaction::Kind::TRANSFER_BETWEEN_ACCOUNTS
      nil
    else
      payment_method.nil? ? transaction.payment_method : payment_method
    end
    effective_ends_on = if effective_recurrence_type == Core::Transaction::RecurrenceType::ONE_TIME
      nil
    else
      ends_on.nil? ? transaction.ends_on : ends_on
    end

    Continue(effective_kind:, effective_payment_method:, effective_recurrence_type:, effective_ends_on:)
  end

  def calculate_installments_count(transaction:, effective_recurrence_type:, effective_ends_on:, starts_on:, **)
    return Continue(installments_count: nil) unless transaction.pending?

    first_starts_on = starts_on || transaction.recurrences.map(&:starts_on).min

    Continue(
      installments_count: Core::Transaction::Installments.calculate(
        recurrence_type: effective_recurrence_type,
        starts_on: first_starts_on,
        ends_on: effective_ends_on
      )
    )
  end

  def validate_payment_method_compatibility(transaction:, effective_kind:, effective_payment_method:, **)
    return Continue() unless transaction.pending?

    Core::Transaction::PaymentMethod.validate_compatibility_with_kind(input.errors, kind: effective_kind, payment_method: effective_payment_method)

    return Failure(:invalid_input, input:) if input.errors.any?

    Continue()
  end

  def ensure_invoice_unpaid(
    user:,
    transaction:,
    starts_on:,
    ends_on:,
    payment_method:,
    credit_card_id:,
    recurrence_type:,
    effective_payment_method:,
    effective_recurrence_type:,
    effective_ends_on:,
    **
  )
    return Continue() unless invoice_unpaid_check_needed?(
      transaction:,
      starts_on:,
      ends_on:,
      payment_method:,
      credit_card_id:,
      recurrence_type:,
      effective_payment_method:
    )

    date_from = starts_on || transaction.recurrences.min_by(&:starts_on)&.starts_on

    with_nested_process(
      Core::CreditCard::InvoiceSettlement::EnsureUnpaid.call(
        user:,
        from: date_from,
        to: invoice_coverage_to(recurrence_type: effective_recurrence_type, starts_on: date_from, ends_on: effective_ends_on),
        payment_method: effective_payment_method,
        credit_card_id: credit_card_id.nil? ? transaction.credit_card_id : credit_card_id
      )
    )
  end

  def invoice_unpaid_check_needed?(
    transaction:,
    starts_on:,
    ends_on:,
    payment_method:,
    credit_card_id:,
    recurrence_type:,
    effective_payment_method:
  )
    return false unless effective_payment_method == Core::Transaction::PaymentMethod::CREDIT_CARD
    return true if starts_on.present? || ends_on.present? || recurrence_type.present?
    return true if payment_method.present? && !transaction.credit_card_payment?
    return true if credit_card_id.present? && !UUID.same?(credit_card_id, transaction.credit_card_id)

    false
  end

  def invoice_coverage_to(recurrence_type:, starts_on:, ends_on:)
    recurrence_type == Core::Transaction::RecurrenceType::ONE_TIME ? starts_on : ends_on
  end

  def ensure_category_belongs_to_user(user:, transaction:, category_id:, **)
    return Continue() if category_id.blank?

    case deps.category_repository.find_by_id(user:, id: category_id)
    in Solid::Success(category:)
      return Continue() if category.active? || UUID.same?(category_id, transaction.category_id)

      input.errors.add(:category_id, :inactive)

      Failure(:invalid_input, input:)
    in Solid::Failure(type: :category_not_found)
      input.errors.add(:category_id, :not_found)
      Failure(:invalid_input, input:)
    end
  end

  def ensure_tags_belong_to_user(user:, transaction:, tag_ids:, **)
    return Continue() if tag_ids.blank?

    linked_tag_ids = Array(transaction.tag_ids).map(&:to_s)

    case deps.tag_repository.find_by_ids(user:, ids: tag_ids)
    in Solid::Success(tags:)
      newly_inactive = tags.reject { |tag| tag.active? || linked_tag_ids.include?(tag.id.to_s) }

      if newly_inactive.any?
        input.errors.add(:tag_ids, :inactive)
        return Failure(:invalid_input, input:)
      end

      Continue()
    in Solid::Failure(type: :tags_not_found)
      input.errors.add(:tag_ids, :not_found)
      Failure(:invalid_input, input:)
    end
  end

  def update_for_account(user:, transaction:, effective_kind:, effective_payment_method:, account_id:, **)
    with_nested_process(
      Core::Transaction::ForAccount::Update.call(
        user:,
        transaction:,
        kind: effective_kind,
        payment_method: effective_payment_method,
        account_id:
      ),
      persist_failure: :transaction_update_failed
    )
  end

  def update_for_credit_card(user:, transaction:, effective_kind:, effective_payment_method:, effective_recurrence_type:, credit_card_id:, limit_consumption_type:, **)
    with_nested_process(
      Core::Transaction::ForCreditCard::Update.call(
        user:,
        transaction:,
        kind: effective_kind,
        payment_method: effective_payment_method,
        recurrence_type: effective_recurrence_type,
        credit_card_id:,
        limit_consumption_type:
      ),
      persist_failure: :transaction_update_failed
    )
  end

  def update_for_transfer_between_accounts(user:, transaction:, effective_kind:, source_account_id:, destination_account_id:, **)
    with_nested_process(
      Core::Transaction::ForTransferBetweenAccounts::Update.call(
        user:,
        transaction:,
        kind: effective_kind,
        source_account_id:,
        destination_account_id:
      ),
      persist_failure: :transaction_update_failed
    )
  end

  def update_recurrence(transaction:, effective_recurrence_type:, effective_ends_on:, starts_on:, value:, **)
    with_nested_process(
      Core::Transaction::Recurrence::Update.call(
        transaction:,
        recurrence_type: effective_recurrence_type,
        starts_on:,
        ends_on: effective_ends_on,
        value:
      ),
      persist_failure: :transaction_update_failed
    )
  end

  def update_transaction(
    transaction:, category_id:, description:, effective_kind:, effective_payment_method:, effective_recurrence_type:, effective_ends_on:, installments_count:, **
  )
    attributes = {}
    attributes[:category_id] = category_id unless category_id.nil?
    attributes[:description] = description unless description.nil?

    if transaction.pending?
      attributes[:kind] = effective_kind
      attributes[:payment_method] = effective_payment_method
      attributes[:recurrence_type] = effective_recurrence_type
      attributes[:ends_on] = effective_ends_on
      attributes[:installments_count] = installments_count
    elsif transaction.active? && transaction.recurrence_type == Core::Transaction::RecurrenceType::RECURRING
      attributes[:ends_on] = effective_ends_on
    end

    return Continue() if attributes.empty?

    case deps.transaction_repository.update(transaction:, attributes:)
    in Solid::Success(transaction:) then Continue(transaction:)
    in Solid::Failure(errors:)
      add_errors_to_input(errors)
      input.errors.add(:base, :transaction_update_failed)

      Failure(:transaction_update_failed, input:)
    end
  end

  def replace_taggings(transaction:, tag_ids:, **)
    return Continue() if tag_ids.nil?

    case deps.tagging_repository.sync(transaction:, tag_ids:)
    in Solid::Success then Continue()
    in Solid::Failure(errors:)
      add_errors_to_input(errors)
      input.errors.add(:base, :transaction_update_failed)

      Failure(:transaction_update_failed, input:)
    end
  end

  def reload_transaction(user:, transaction:, **)
    case deps.transaction_repository.find_by_id(user:, id: transaction.id)
    in Solid::Success(transaction:) then Continue(transaction:)
    in Solid::Failure
      input.errors.add(:base, :transaction_update_failed)

      Failure(:transaction_update_failed, input:)
    end
  end

  def reject_provided_fields(attributes, fields)
    fields.each do |field|
      input.errors.add(field, :cannot_be_changed) unless attributes[field].nil?
    end
  end
end
