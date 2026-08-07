module Category::Mapper
  extend self

  def to_entity(record)
    return if record.nil?

    Core::Category::Entity.new(
      id: record.id,
      user_id: record.user_id,
      name: record.name,
      color: record.color,
      active: record.active
    )
  end

  def to_entities(records)
    records.map { |record| to_entity(record) }
  end

  def to_record(entity)
    Category::Record.find(entity.id)
  end

  def to_errors(record)
    Core::Errors.new(record.errors.messages)
  end
end
