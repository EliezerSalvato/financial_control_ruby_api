class Core::Transaction::ForCreditCard::Update < ApplicationSolidProcess
  deps do
    attribute :credit_card_repository, default: -> { CreditCard::Adapters.repository }
    attribute :transaction_for_credit_card_repository, default: -> { Transaction::Adapters.transaction_for_credit_card_repository }

    validates :credit_card_repository, kind_of: Core::CreditCard::Repository::Interface
    validates :transaction_for_credit_card_repository, kind_of: Core::Transaction::ForCreditCard::Repository::Interface
  end

  input do
    attribute :user
    attribute :transaction
    attribute :kind, :string
    attribute :payment_method, :string
    attribute :recurrence_type, :string
    attribute :credit_card_id, :string
    attribute :limit_consumption_type, :string

    validates :user, :transaction, presence: true
    validates :user, kind_of: Core::User::Entity
    validates :transaction, kind_of: Core::Transaction::Entity
  end

  def call(attributes)
    return Continue() if input.transaction.completed_or_canceled?

    if input.payment_method == Core::Transaction::PaymentMethod::CREDIT_CARD
      Given(attributes)
        .and_then(:resolve_credit_card)
        .and_then(:apply_limit_consumption_default)
        .and_then(:validate_presence)
        .and_then(:validate_limit_consumption)
        .and_then(:ensure_credit_card_belongs_to_user)
        .and_then(:upsert_for_credit_card)
    else
      destroy_for_credit_card(transaction: input.transaction)
    end
  end

  private

  def resolve_credit_card(transaction:, credit_card_id:, limit_consumption_type:, recurrence_type:, **)
    credit_card_id = credit_card_id.nil? ? transaction.credit_card_id : credit_card_id

    if limit_consumption_type.nil? && recurrence_type == Core::Transaction::RecurrenceType::INSTALLMENT
      limit_consumption_type = transaction.limit_consumption_type
    end

    Continue(credit_card_id:, limit_consumption_type:)
  end

  def apply_limit_consumption_default(transaction:, payment_method:, recurrence_type:, limit_consumption_type:, **)
    return Continue() unless transaction.pending?

    Continue(limit_consumption_type: Core::Transaction::LimitConsumptionType.default_for(payment_method:, recurrence_type:, limit_consumption_type:))
  end

  def validate_presence(credit_card_id:, **)
    input.errors.add(:credit_card_id, :blank) if credit_card_id.blank?

    return Failure(:invalid_input, input:) if input.errors.any?

    Continue()
  end

  def validate_limit_consumption(transaction:, payment_method:, recurrence_type:, limit_consumption_type:, **)
    return Continue() unless transaction.pending?
    return Continue() unless payment_method == Core::Transaction::PaymentMethod::CREDIT_CARD
    return Continue() unless recurrence_type == Core::Transaction::RecurrenceType::INSTALLMENT

    input.errors.add(:limit_consumption_type, :blank) if limit_consumption_type.blank?

    return Failure(:invalid_input, input:) if input.errors.any?

    Continue()
  end

  def ensure_credit_card_belongs_to_user(user:, transaction:, credit_card_id:, **)
    case deps.credit_card_repository.find_by_id(user:, id: credit_card_id)
    in Solid::Success(credit_card:)
      return Continue() if credit_card.active? || UUID.same?(credit_card_id, transaction.credit_card_id)

      input.errors.add(:credit_card_id, :inactive)
      Failure(:invalid_input, input:)
    in Solid::Failure(type: :credit_card_not_found)
      input.errors.add(:credit_card_id, :not_found)
      Failure(:invalid_input, input:)
    end
  end

  def upsert_for_credit_card(transaction:, credit_card_id:, limit_consumption_type:, **)
    case deps.transaction_for_credit_card_repository.upsert(transaction:, credit_card_id:, limit_consumption_type:)
    in Solid::Success then Continue()
    in Solid::Failure(errors:)
      add_errors_to_input(errors)
      Failure(:for_credit_card_upsert_failed, errors:)
    end
  end

  def destroy_for_credit_card(transaction:)
    case deps.transaction_for_credit_card_repository.destroy(transaction:)
    in Solid::Success then Continue()
    in Solid::Failure(errors:)
      add_errors_to_input(errors)
      Failure(:for_credit_card_destruction_failed, errors:)
    end
  end
end
