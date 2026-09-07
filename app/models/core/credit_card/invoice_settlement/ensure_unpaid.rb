class Core::CreditCard::InvoiceSettlement::EnsureUnpaid < ApplicationSolidProcess
  deps do
    attribute :invoice_settlement_repository, default: -> { CreditCard::Adapters.invoice_settlement_repository }

    validates :invoice_settlement_repository, kind_of: Core::CreditCard::InvoiceSettlement::Repository::Interface
  end

  input do
    attribute :from, :date
    attribute :to, :date
    attribute :payment_method, :string
    attribute :credit_card_id, :string

    validates :from, presence: true
  end

  def call(attributes)
    Given(attributes)
      .and_then(:reject_if_invoice_paid)
  end

  private

  def reject_if_invoice_paid(payment_method:, credit_card_id:, from:, to:, **)
    return Continue() unless payment_method == Core::Transaction::PaymentMethod::CREDIT_CARD && credit_card_id.present?
    return Continue() unless deps.invoice_settlement_repository.paid_covering?(credit_card_id:, from:, to:)

    input.errors.add(:base, :invoice_already_paid)
    Failure(:invoice_already_paid, input:)
  end
end
