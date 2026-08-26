module CreditCard::Mapper
  extend self

  def to_entity(record)
    return if record.nil?

    Core::CreditCard::Entity.new(
      id: record.id,
      user_id: record.user_id,
      institution_id: record.institution_id,
      default_payment_account_id: record.default_payment_account_id,
      name: record.name,
      total_limit: record.total_limit,
      available_limit: record.available_limit,
      closing_day: record.closing_day,
      due_day: record.due_day,
      network: record.network,
      allow_negative_available_limit: record.allow_negative_available_limit,
      active: record.active
    )
  end

  def to_entities(records)
    records.map { |record| to_entity(record) }
  end

  def to_record(entity)
    CreditCard::Record.find(entity.id)
  end

  def to_errors(record)
    Core::Errors.new(record.errors.messages)
  end
end
