module MonthlyStatement::Transfer::Mapper
  extend self

  def to_entity(record)
    return if record.nil?

    Core::MonthlyStatement::Transfer::Entity.new(
      id: record.id,
      kind: record.kind,
      description: record.description,
      recurrence_type: record.recurrence_type,
      source_account_id: record.source_account_id,
      source_account_name: record.source_account_name,
      source_account_brand: record.source_account_brand,
      destination_account_id: record.destination_account_id,
      destination_account_name: record.destination_account_name,
      destination_account_brand: record.destination_account_brand,
      opening_date: record.opening_date,
      closing_date: record.closing_date,
      value: record.value,
      first_recurrence_on: record.first_recurrence_on,
      current_recurrence_on: record.current_recurrence_on,
      starts_on: record.starts_on,
      ends_on: record.ends_on,
      canceled_on: record.canceled_on
    )
  end

  def to_entities(records)
    records.map { |record| to_entity(record) }
  end
end
