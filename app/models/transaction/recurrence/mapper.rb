module Transaction::Recurrence::Mapper
  extend self

  def to_entity(record)
    return if record.nil?

    Core::Transaction::Recurrence::Entity.new(
      id: record.id,
      starts_on: record.starts_on,
      value: record.value
    )
  end

  def to_record(entity)
    Transaction::Recurrence::Record.find(entity.id)
  end

  def to_errors(record)
    Core::Errors.new(record.errors.messages)
  end
end
