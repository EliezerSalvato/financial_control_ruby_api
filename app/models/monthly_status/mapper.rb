module MonthlyStatus::Mapper
  extend self

  def to_entity(record)
    return if record.nil?

    Core::MonthlyStatus::Entity.new(
      id: record.id,
      user_id: record.user_id,
      month: record.month,
      year: record.year,
      status: record.status
    )
  end

  def to_entities(records)
    records.map { |record| to_entity(record) }
  end

  def to_record(entity)
    MonthlyStatus::Record.find(entity.id)
  end

  def to_errors(record)
    Core::Errors.new(record.errors.messages)
  end
end
