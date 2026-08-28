module CreditCard::InvoiceSettlement::Repository::Adapters::ActiveRecord
  include Core::CreditCard::InvoiceSettlement::Repository::Interface
  extend Solid::Output.mixin
  extend self

  def list_due(user_id:, month:, year:, reference_date:)
    records = CreditCard::InvoiceSettlement::Due::Record.for_period(user_id:, month:, year:, reference_date:)

    Success(:credit_card_due_invoices_listed, due_invoices: CreditCard::InvoiceSettlement::Due::Mapper.to_entities(records))
  end
end
