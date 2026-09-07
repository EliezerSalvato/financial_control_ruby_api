module CreditCard::InvoiceSettlement::Due::Mapper
  extend self

  def to_entity(record)
    return if record.nil?

    Core::CreditCard::InvoiceSettlement::Due.new(
      credit_card_id: record.credit_card_id,
      credit_card_name: record.credit_card_name,
      payment_account_id: record.payment_account_id,
      opening_date: record.opening_date,
      closing_date: record.closing_date,
      due_date: record.due_date,
      total_value: record.total_value
    )
  end

  def to_entities(records)
    records.map { |record| to_entity(record) }
  end
end
