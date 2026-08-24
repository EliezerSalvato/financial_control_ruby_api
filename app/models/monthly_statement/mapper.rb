module MonthlyStatement::Mapper
  extend self

  def to_entity(record)
    return if record.nil?

    Core::MonthlyStatement::Entity.new(
      id: record.id,
      kind: record.kind,
      description: record.description,
      recurrence_type: record.recurrence_type,
      payment_method: record.payment_method,
      resource_id: record.resource_id,
      resource_name: record.resource_name,
      resource_brand: record.resource_brand,
      opening_date: record.opening_date,
      closing_date: record.closing_date,
      due_date: record.due_date,
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
