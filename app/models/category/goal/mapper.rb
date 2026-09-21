module Category::Goal::Mapper
  extend self

  def to_entity(record)
    return if record.nil?

    Core::Category::Goal::Entity.new(
      id: record.id,
      month: record.month,
      year: record.year,
      value: record.value
    )
  end

  def to_record(entity)
    Category::Goal::Record.find(entity.id)
  end

  def to_errors(record)
    Core::Errors.new(record.errors.messages)
  end
end
