module Account::Mapper
  extend self

  def to_entity(record)
    return if record.nil?

    Core::Account::Entity.new(
      id: record.id,
      user_id: record.user_id,
      institution_id: record.institution_id,
      name: record.name,
      kind: record.kind,
      bank_account_type: record.bank_account_type,
      current_balance: record.current_balance,
      color: record.color,
      allow_negative_balance: record.allow_negative_balance,
      active: record.active
    )
  end

  def to_entities(records)
    records.map { |record| to_entity(record) }
  end

  def to_record(entity)
    Account::Record.find(entity.id)
  end

  def to_errors(record)
    Core::Errors.new(record.errors.messages)
  end
end
