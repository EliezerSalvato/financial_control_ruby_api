module Institution::Mapper
  extend self

  def to_entity(record)
    return if record.nil?

    Core::Institution::Entity.new(
      id: record.id,
      user_id: record.user_id,
      name: record.name,
      logo_key: record.logo_key,
      active: record.active
    )
  end

  def to_entities(records)
    records.map { |record| to_entity(record) }
  end

  def to_record(entity)
    Institution::Record.find(entity.id)
  end

  def to_errors(record)
    Core::Errors.new(record.errors.messages)
  end
end
