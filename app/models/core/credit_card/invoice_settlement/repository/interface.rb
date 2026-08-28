module Core::CreditCard::InvoiceSettlement::Repository::Interface
  include Solid::Adapters::Interface

  module Methods
    def list_due(user_id:, month:, year:, reference_date:)
      user_id => String
      month => Integer
      year => Integer
      reference_date => Date

      super.tap do
        _1 => Solid::Success(:credit_card_due_invoices_listed, { due_invoices: Array })
      end
    end
  end
end
