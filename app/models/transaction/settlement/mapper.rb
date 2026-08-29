module Transaction::Settlement::Mapper
  extend self

  def to_entity(record)
    return if record.nil?

    Core::Transaction::Settlement::Entity.new(
      id: record.id,
      transaction_id: record.transaction_id,
      occurred_on: record.occurred_on,
      settled_on: record.settled_on,
      value: record.value,
      installment_number: record.installment_number,
      account_id: record.for_account&.account_id,
      source_account_id: record.for_transfer_between_accounts&.source_account_id,
      destination_account_id: record.for_transfer_between_accounts&.destination_account_id,
      limit_consumed: record.for_credit_card&.limit_consumed,
      credit_card_invoice_settlement_id: record.for_credit_card&.credit_card_invoice_settlement_id
    )
  end

  def to_errors(record)
    Core::Errors.new(record.errors.messages)
  end
end
