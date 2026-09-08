class Core::CreditCard::InvoiceSettlement::Listing < ApplicationSolidProcess
  deps do
    attribute :invoice_settlement_repository, default: -> { CreditCard::Adapters.invoice_settlement_repository }

    validates :invoice_settlement_repository, kind_of: Core::CreditCard::InvoiceSettlement::Repository::Interface
  end

  input do
    attribute :user
    attribute :month, :integer
    attribute :year, :integer

    validates :user, presence: true, kind_of: Core::User::Entity
    validates :month, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 12 }
    validates :year, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 9999 }
  end

  def call(attributes)
    Given(attributes)
      .and_then(:list_invoice_settlements)
  end

  private

  def list_invoice_settlements(user:, month:, year:, **)
    case deps.invoice_settlement_repository.list_for_month(user:, month:, year:)
    in Solid::Success(invoice_settlements:)
      Continue(invoice_settlements:)
    end
  end
end
