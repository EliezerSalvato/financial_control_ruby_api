module CreditCard::InvoiceSettlement::Repository::Adapters::ActiveRecord
  include Core::CreditCard::InvoiceSettlement::Repository::Interface
  extend Solid::Output.mixin
  extend self

  def list_due(user_id:, month:, year:, reference_date:)
    records = CreditCard::InvoiceSettlement::Due::Record.for_period(user_id:, month:, year:, reference_date:)

    Success(:credit_card_due_invoices_listed, due_invoices: CreditCard::InvoiceSettlement::Due::Mapper.to_entities(records))
  end

  def create(credit_card_id:, payment_account_id:, opening_date:, closing_date:, due_date:, total_value:, released_limit:, settled_on:)
    ApplicationRecord.transaction(requires_new: true) do
      record = CreditCard::InvoiceSettlement::Record.create!(
        credit_card_id:,
        payment_account_id:,
        opening_date:,
        closing_date:,
        due_date:,
        total_value:,
        released_limit:,
        settled_on:
      )

      Success(:credit_card_invoice_settlement_created, invoice_settlement: CreditCard::InvoiceSettlement::Mapper.to_entity(record))
    end
  rescue ActiveRecord::RecordNotUnique
    existing = CreditCard::InvoiceSettlement::Record.find_by!(credit_card_id:, due_date:)
    Success(:already_settled, invoice_settlement: CreditCard::InvoiceSettlement::Mapper.to_entity(existing))
  rescue ActiveRecord::RecordInvalid => e
    Failure(:credit_card_invoice_settlement_creation_failed, errors: CreditCard::InvoiceSettlement::Mapper.to_errors(e.record))
  end

  def link_occurrences(invoice_settlement:)
    card_transaction_ids = Transaction::ForCreditCard::Record
      .where(credit_card_id: invoice_settlement.credit_card_id)
      .select(:transaction_id)

    linked_count = Transaction::Settlement::ForCreditCard::Record
      .joins(:transaction_settlement)
      .where(credit_card_invoice_settlement_id: nil)
      .where(
        transaction_settlements: {
          occurred_on: invoice_settlement.opening_date..invoice_settlement.closing_date,
          transaction_id: card_transaction_ids
        }
      )
      .update_all(credit_card_invoice_settlement_id: invoice_settlement.id)

    Success(:credit_card_invoice_occurrences_linked, linked_count:)
  end

  def paid_keys(credit_card_ids:, due_dates:)
    keys = CreditCard::InvoiceSettlement::Record
      .where(credit_card_id: credit_card_ids, due_date: due_dates)
      .pluck(:credit_card_id, :due_date)

    Success(:credit_card_invoice_settlements_listed, keys:)
  end
end
