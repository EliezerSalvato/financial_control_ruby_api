class Core::CreditCard::InvoiceSettlement::EnsureUnpaid < ApplicationSolidProcess
  deps do
    attribute :credit_card_repository, default: -> { CreditCard::Adapters.repository }
    attribute :invoice_settlement_repository, default: -> { CreditCard::Adapters.invoice_settlement_repository }

    validates :credit_card_repository, kind_of: Core::CreditCard::Repository::Interface
    validates :invoice_settlement_repository, kind_of: Core::CreditCard::InvoiceSettlement::Repository::Interface
  end

  input do
    attribute :user
    attribute :from, :date
    attribute :to, :date
    attribute :payment_method, :string
    attribute :credit_card_id, :string

    validates :user, presence: true, kind_of: Core::User::Entity
    validates :from, presence: true
  end

  def call(attributes)
    Given(attributes)
      .and_then(:ensure_credit_card_belongs_to_user)
      .and_then(:reject_if_invoice_paid)
  end

  private

  def ensure_credit_card_belongs_to_user(user:, payment_method:, credit_card_id:, **)
    return Continue() unless credit_card_payment?(payment_method:, credit_card_id:)

    case deps.credit_card_repository.find_by_id(user:, id: credit_card_id)
    in Solid::Success then Continue()
    in Solid::Failure(type: :credit_card_not_found)
      input.errors.add(:credit_card_id, :not_found)
      Failure(:invalid_input, input:)
    end
  end

  def reject_if_invoice_paid(payment_method:, credit_card_id:, from:, to:, **)
    return Continue() unless credit_card_payment?(payment_method:, credit_card_id:)
    return Continue() unless deps.invoice_settlement_repository.paid_covering?(credit_card_id:, from:, to:)

    input.errors.add(:base, :invoice_already_paid)
    Failure(:invoice_already_paid, input:)
  end

  def credit_card_payment?(payment_method:, credit_card_id:)
    payment_method == Core::Transaction::PaymentMethod::CREDIT_CARD && credit_card_id.present?
  end
end
