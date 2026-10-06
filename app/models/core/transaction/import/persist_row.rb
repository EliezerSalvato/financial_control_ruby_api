class Core::Transaction::Import::PersistRow < ApplicationSolidProcess
  deps do
    attribute :user_repository, default: -> { User::Adapters.repository }
    attribute :transaction_repository, default: -> { Transaction::Adapters.repository }
    attribute :category_repository, default: -> { Category::Adapters.repository }
    attribute :tag_repository, default: -> { Tag::Adapters.repository }

    validates :user_repository, kind_of: Core::User::Repository::Interface
    validates :transaction_repository, kind_of: Core::Transaction::Repository::Interface
    validates :category_repository, kind_of: Core::Category::Repository::Interface
    validates :tag_repository, kind_of: Core::Tag::Repository::Interface
  end

  input do
    attribute :user_id, :string
    attribute :create, :boolean, default: true
    attribute :source_key, :string
    attribute :date, :date
    attribute :description, :string
    attribute :amount, :decimal
    attribute :kind, :string
    attribute :payment_method, :string
    attribute :account_id, :string
    attribute :credit_card_id, :string
    attribute :limit_consumption_type, :string
    attribute :installments_count, :integer
    attribute :recurrence_type, :string, default: Core::Transaction::RecurrenceType::ONE_TIME
    attribute :ends_on, :date
    attribute :category_id, :string
    attribute :category_name, :string
    attribute :tag_ids, default: -> { [] }
    attribute :tag_names, default: -> { [] }

    normalizes :source_key, :category_id, :category_name, with: ->(value) { value&.strip.presence }
    normalizes :tag_ids, with: ->(value) { value.to_a.map { |id| id.to_s.strip.presence }.compact.uniq }
    normalizes :tag_names, with: ->(value) { value.to_a.map { |name| name.to_s.strip.presence }.compact.uniq(&:downcase) }

    validates :user_id, presence: true
    validates :installments_count, numericality: { only_integer: true, greater_than: 1 }, allow_nil: true
  end

  def call(attributes)
    return Success(:ignored) if ActiveModel::Type::Boolean.new.cast(attributes.fetch(:create, true)) == false

    rollback_on_failure {
      Given(attributes)
        .and_then(:validate_installment_fields)
        .and_then(:find_user)
        .and_then(:ensure_not_imported)
        .and_then(:resolve_category)
        .and_then(:resolve_tags)
        .and_then(:create_transaction)
    }
  end

  private

  # installments_count and limit_consumption_type belong exclusively to installment transactions.
  def validate_installment_fields(recurrence_type:, payment_method:, installments_count:, limit_consumption_type:, **)
    if recurrence_type == Core::Transaction::RecurrenceType::INSTALLMENT
      input.errors.add(:installments_count, :blank) if installments_count.nil?
      if payment_method == Core::Transaction::PaymentMethod::CREDIT_CARD && limit_consumption_type.blank?
        input.errors.add(:limit_consumption_type, :blank)
      end
    else
      input.errors.add(:installments_count, :present) unless installments_count.nil?
      input.errors.add(:limit_consumption_type, :present) if limit_consumption_type.present?
    end

    return Failure(:invalid_input, input:) if input.errors.any?

    Continue()
  end

  def find_user(user_id:, **)
    case deps.user_repository.find_by_id(id: user_id)
    in Solid::Success(user:) then Continue(user:)
    in Solid::Failure(type: :user_not_found) then Failure(:user_not_found)
    end
  end

  def ensure_not_imported(user:, source_key:, **)
    return Continue() if source_key.blank?
    return Continue() unless deps.transaction_repository.exists_by_source_key?(user:, source_key:)

    Failure(:already_imported)
  end

  def resolve_category(user:, category_id:, category_name:, **)
    return Continue() if category_id.present?

    if category_name.blank?
      input.errors.add(:category_id, :blank)
      return Failure(:invalid_input, input:)
    end

    case deps.category_repository.find_or_create_by_name(user:, name: category_name, color: Core::Color.random)
    in Solid::Success(category:) then Continue(category_id: category.id)
    in Solid::Failure
      input.errors.add(:base, :category_creation_failed)

      Failure(:invalid_input, input:)
    end
  end

  def resolve_tags(user:, tag_ids:, tag_names:, **)
    return Continue() if tag_names.empty?

    case deps.tag_repository.find_or_create_by_names(user:, names: tag_names, color: Core::Color.random)
    in Solid::Success(tags:) then Continue(tag_ids: (tag_ids + tags.map(&:id)).uniq)
    in Solid::Failure
      input.errors.add(:base, :tag_creation_failed)

      Failure(:invalid_input, input:)
    end
  end

  def create_transaction(user:, source_key:, date:, **attributes)
    result = Core::Transaction::Creation.call(
      user:,
      source_key:,
      starts_on: date,
      ends_on: ends_on_for(date:, **attributes.slice(:recurrence_type, :installments_count, :ends_on)),
      value: attributes[:amount],
      **attributes.slice(
        :category_id, :description, :kind, :payment_method, :recurrence_type,
        :limit_consumption_type, :account_id, :credit_card_id, :tag_ids
      )
    )

    case result
    in Solid::Success(transaction:) then Success(:transaction_created, transaction:)
    in Solid::Failure(type: :already_imported) then Failure(:already_imported)
    in Solid::Failure(input: creation_input) then Failure(:invalid_transaction, input: creation_input)
    end
  end

  def ends_on_for(date:, recurrence_type:, installments_count:, ends_on:)
    return ends_on unless recurrence_type == Core::Transaction::RecurrenceType::INSTALLMENT

    date >> (installments_count - 1)
  end
end
