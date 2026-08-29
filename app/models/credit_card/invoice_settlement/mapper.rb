module CreditCard::InvoiceSettlement::Mapper
  extend self

  def to_entity(record)
    return if record.nil?

    Core::CreditCard::InvoiceSettlement::Entity.new(
      id: record.id,
      credit_card_id: record.credit_card_id,
      payment_account_id: record.payment_account_id,
      opening_date: record.opening_date,
      closing_date: record.closing_date,
      due_date: record.due_date,
      total_value: record.total_value,
      released_limit: record.released_limit,
      settled_on: record.settled_on
    )
  end

  def to_errors(record)
    Core::Errors.new(record.errors.messages)
  end
end
