class Core::Transaction::ForCreditCard::Creation < ApplicationSolidProcess
  deps do
    attribute :credit_card_repository, default: -> { CreditCard::Adapters.repository }
    attribute :transaction_for_credit_card_repository, default: -> { Transaction::Adapters.transaction_for_credit_card_repository }

    validates :credit_card_repository, kind_of: Core::CreditCard::Repository::Interface
    validates :transaction_for_credit_card_repository, kind_of: Core::Transaction::ForCreditCard::Repository::Interface
  end

  input do
    attribute :user
    attribute :transaction
    attribute :payment_method, :string
    attribute :recurrence_type, :string
    attribute :credit_card_id, :string
    attribute :limit_consumption_type, :string

    validates :user, :transaction, :credit_card_id, presence: true
    validates :user, kind_of: Core::User::Entity
    validates :transaction, kind_of: Core::Transaction::Entity
  end

  def call(attributes)
    Given(attributes)
      .and_then(:apply_limit_consumption_default)
      .and_then(:validate_limit_consumption)
      .and_then(:ensure_credit_card_belongs_to_user)
      .and_then(:create_transaction_for_credit_card)
  end

  private

  def apply_limit_consumption_default(payment_method:, recurrence_type:, limit_consumption_type:, **)
    Continue(limit_consumption_type: Core::Transaction::LimitConsumptionType.default_for(payment_method:, recurrence_type:, limit_consumption_type:))
  end

  def validate_limit_consumption(payment_method:, recurrence_type:, limit_consumption_type:, **)
    return Continue() unless payment_method == Core::Transaction::PaymentMethod::CREDIT_CARD
    return Continue() if recurrence_type == Core::Transaction::RecurrenceType::ONE_TIME

    input.errors.add(:limit_consumption_type, :blank) if limit_consumption_type.blank?

    return Failure(:invalid_input, input:) if input.errors.any?

    Continue()
  end

  def ensure_credit_card_belongs_to_user(user:, credit_card_id:, **)
    case deps.credit_card_repository.find_by_id(user:, id: credit_card_id)
    in Solid::Success(credit_card:)
      return Continue() if credit_card.active?

      input.errors.add(:credit_card_id, :inactive)
      Failure(:invalid_input, input:)
    in Solid::Failure(type: :credit_card_not_found)
      input.errors.add(:credit_card_id, :not_found)
      Failure(:invalid_input, input:)
    end
  end

  def create_transaction_for_credit_card(transaction:, credit_card_id:, limit_consumption_type:, **)
    case deps.transaction_for_credit_card_repository.create(transaction:, credit_card_id:, limit_consumption_type:)
    in Solid::Success then Continue()
    in Solid::Failure(errors:)
      add_errors_to_input(errors)
      Failure(:for_credit_card_creation_failed, errors:)
    end
  end
end
