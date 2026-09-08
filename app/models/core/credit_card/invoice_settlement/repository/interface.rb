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

    def create(credit_card_id:, payment_account_id:, opening_date:, closing_date:, due_date:, total_value:, released_limit:, settled_on:)
      credit_card_id => String
      payment_account_id => String
      opening_date => Date
      closing_date => Date
      due_date => Date
      total_value => Numeric
      released_limit => Numeric
      settled_on => Date

      super.tap do
        _1 => (
          Solid::Success(:credit_card_invoice_settlement_created, { invoice_settlement: Core::CreditCard::InvoiceSettlement::Entity }) |
          Solid::Success(:already_settled, { invoice_settlement: Core::CreditCard::InvoiceSettlement::Entity }) |
          Solid::Failure(:credit_card_invoice_settlement_creation_failed, { errors: Core::Errors })
        )
      end
    end

    def link_occurrences(invoice_settlement:)
      invoice_settlement => Core::CreditCard::InvoiceSettlement::Entity

      super.tap do
        _1 => Solid::Success(:credit_card_invoice_occurrences_linked, { linked_count: Integer })
      end
    end

    def list_for_month(user:, month:, year:)
      user => Core::User::Entity
      month => Integer
      year => Integer

      super.tap do
        _1 => Solid::Success(:invoice_settlements_listed, { invoice_settlements: Array })
      end
    end

    def paid_keys(credit_card_ids:, due_dates:)
      credit_card_ids => Array
      due_dates => Array

      super.tap do
        _1 => Solid::Success(:credit_card_invoice_settlements_listed, { keys: Array })
      end
    end

    def paid_covering?(credit_card_id:, from:, to:)
      credit_card_id => String
      from => Date
      to => Date | NilClass

      super.tap do
        _1 => true | false
      end
    end
  end
end
