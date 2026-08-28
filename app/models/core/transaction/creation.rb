class Core::Transaction::Creation < ApplicationSolidProcess
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
    attribute :category_id, :string
    attribute :description, :string
    attribute :kind, :string
    attribute :payment_method, :string
    attribute :recurrence_type, :string
    attribute :starts_on, :date
    attribute :ends_on, :date
    attribute :value, :decimal
    attribute :limit_consumption_type, :string
    attribute :account_id, :string
    attribute :credit_card_id, :string
    attribute :source_account_id, :string
    attribute :destination_account_id, :string
    attribute :tag_ids, default: -> { [] }

    normalizes :description, with: ->(value) { value&.strip }
    normalizes :kind, :payment_method, :recurrence_type, :limit_consumption_type, with: ->(value) { value&.strip.presence }
    normalizes :category_id, :account_id, :credit_card_id, :source_account_id, :destination_account_id, with: ->(value) { value&.strip.presence }
    normalizes :tag_ids, with: ->(value) { value.to_a.map { |id| id.to_s.strip.presence }.compact.uniq }

    validates :user, :description, :category_id, :kind, :recurrence_type, :starts_on, :value, presence: true
    validates :user, kind_of: Core::User::Entity
    validates :kind, inclusion: { in: Core::Transaction::Kind::ALL }
    validates :recurrence_type, inclusion: { in: Core::Transaction::RecurrenceType::ALL }
    validates :value, numericality: { greater_than_or_equal_to: 0 }
    validates :limit_consumption_type, inclusion: { in: Core::Transaction::LimitConsumptionType::ALL }, allow_nil: true
    validates :payment_method, inclusion: { in: Core::Transaction::PaymentMethod::ALL }, allow_nil: true
  end

  def call(attributes)
    rollback_on_failure {
      Given(attributes)
        .and_then(:validate_payment_method_compatibility)
        .and_then(:validate_recurrence)
        .and_then(:ensure_month_is_open)
        .and_then(:calculate_installments_count)
        .and_then(:ensure_category_belongs_to_user)
        .and_then(:ensure_tags_belong_to_user)
        .and_then(:create_transaction)
        .and_then(:create_for_account)
        .and_then(:create_for_credit_card)
        .and_then(:create_for_transfer_between_accounts)
        .and_then(:create_recurrence)
        .and_then(:replace_taggings)
        .and_then(:reload_transaction)
    }
  end

  private

  def validate_payment_method_compatibility(kind:, payment_method:, **)
    Core::Transaction::PaymentMethod.validate_compatibility_with_kind(input.errors, kind:, payment_method:)

    return Failure(:invalid_input, input:) if input.errors.any?

    Continue()
  end

  def validate_recurrence(recurrence_type:, starts_on:, ends_on:, **)
    Core::Transaction::RecurrenceType.validate_compatibility_with_ends_on(input.errors, recurrence_type:, starts_on:, ends_on:)

    return Failure(:invalid_input, input:) if input.errors.any?

    Continue()
  end

  def ensure_month_is_open(user:, starts_on:, payment_method:, credit_card_id:, **)
    with_nested_process(
      Core::MonthlyStatus::EnsureOpen.call(user:, date: starts_on, payment_method:, credit_card_id:)
    )
  end

  def calculate_installments_count(recurrence_type:, starts_on:, ends_on:, **)
    Continue(installments_count: Core::Transaction::Installments.calculate(recurrence_type:, starts_on:, ends_on:))
  end

  def ensure_category_belongs_to_user(user:, category_id:, **)
    return Continue() if category_id.blank?

    case deps.category_repository.find_by_id(user:, id: category_id)
    in Solid::Success(category:)
      return Continue() if category.active?

      input.errors.add(:category_id, :inactive)
      Failure(:invalid_input, input:)
    in Solid::Failure(type: :category_not_found)
      input.errors.add(:category_id, :not_found)
      Failure(:invalid_input, input:)
    end
  end

  def ensure_tags_belong_to_user(user:, tag_ids:, **)
    return Continue() if tag_ids.blank?

    case deps.tag_repository.find_by_ids(user:, ids: tag_ids)
    in Solid::Success(tags:)
      unless tags.all?(&:active?)
        input.errors.add(:tag_ids, :inactive)
        return Failure(:invalid_input, input:)
      end

      Continue()
    in Solid::Failure(type: :tags_not_found)
      input.errors.add(:tag_ids, :not_found)
      Failure(:invalid_input, input:)
    end
  end

  def create_transaction(
    user:, category_id:, description:, kind:, payment_method:, recurrence_type:, ends_on:, installments_count: nil, **
  )
    attributes = {
      category_id:,
      description:,
      kind:,
      status: Core::Transaction::Status::PENDING,
      payment_method:,
      recurrence_type:,
      installments_count:,
      ends_on:
    }

    case deps.transaction_repository.create(user:, attributes:)
    in Solid::Success(transaction:) then Continue(transaction:)
    in Solid::Failure(errors:)
      add_errors_to_input(errors)
      input.errors.add(:base, :transaction_creation_failed)
      Failure(:transaction_creation_failed, input:)
    end
  end

  def create_for_account(user:, transaction:, kind:, payment_method:, account_id:, **)
    return Continue() if kind == Core::Transaction::Kind::TRANSFER_BETWEEN_ACCOUNTS || payment_method == Core::Transaction::PaymentMethod::CREDIT_CARD

    with_nested_process(
      Core::Transaction::ForAccount::Creation.call(
        user:,
        transaction:,
        account_id:
      ),
      persist_failure: :transaction_creation_failed
    )
  end

  def create_for_credit_card(user:, transaction:, payment_method:, recurrence_type:, credit_card_id:, limit_consumption_type:, **)
    return Continue() unless payment_method == Core::Transaction::PaymentMethod::CREDIT_CARD

    with_nested_process(
      Core::Transaction::ForCreditCard::Creation.call(
        user:,
        transaction:,
        payment_method:,
        recurrence_type:,
        credit_card_id:,
        limit_consumption_type:
      ),
      persist_failure: :transaction_creation_failed
    )
  end

  def create_for_transfer_between_accounts(user:, transaction:, kind:, source_account_id:, destination_account_id:, **)
    return Continue() unless kind == Core::Transaction::Kind::TRANSFER_BETWEEN_ACCOUNTS

    with_nested_process(
      Core::Transaction::ForTransferBetweenAccounts::Creation.call(
        user:,
        transaction:,
        source_account_id:,
        destination_account_id:
      ),
      persist_failure: :transaction_creation_failed
    )
  end

  def create_recurrence(transaction:, recurrence_type:, starts_on:, ends_on:, value:, **)
    with_nested_process(
      Core::Transaction::Recurrence::Creation.call(
        transaction:,
        recurrence_type:,
        starts_on:,
        ends_on:,
        value:
      ),
      persist_failure: :transaction_creation_failed
    )
  end

  def replace_taggings(transaction:, tag_ids:, **)
    case deps.tagging_repository.sync(transaction:, tag_ids:)
    in Solid::Success then Continue()
    in Solid::Failure(errors:)
      add_errors_to_input(errors)
      input.errors.add(:base, :transaction_creation_failed)
      Failure(:transaction_creation_failed, input:)
    end
  end

  def reload_transaction(user:, transaction:, **)
    case deps.transaction_repository.find_by_id(user:, id: transaction.id)
    in Solid::Success(transaction:) then Continue(transaction:)
    in Solid::Failure
      input.errors.add(:base, :transaction_creation_failed)
      Failure(:transaction_creation_failed, input:)
    end
  end
end
