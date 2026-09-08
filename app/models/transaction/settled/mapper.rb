module Transaction::Settled::Mapper
  extend self

  def to_entity(record)
    return if record.nil?

    transaction = record.financial_transaction

    Core::Transaction::Settled::Entity.new(
      id: record.id,
      transaction_id: record.transaction_id,
      category_id: transaction.category_id,
      description: transaction.description,
      kind: transaction.kind,
      status: transaction.status,
      payment_method: transaction.payment_method,
      recurrence_type: transaction.recurrence_type,
      installments_count: transaction.installments_count,
      ends_on: transaction.ends_on,
      canceled_on: transaction.canceled_on,
      occurred_on: record.occurred_on,
      settled_on: record.settled_on,
      value: record.value,
      installment_number: record.installment_number,
      account_id: record.for_account&.account_id,
      credit_card_id: transaction.for_credit_card&.credit_card_id,
      limit_consumption_type: transaction.for_credit_card&.limit_consumption_type,
      source_account_id: record.for_transfer_between_accounts&.source_account_id,
      destination_account_id: record.for_transfer_between_accounts&.destination_account_id
    )
  end

  def to_entities(records)
    records.map { |record| to_entity(record) }
  end
end
