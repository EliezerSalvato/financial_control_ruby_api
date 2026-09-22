module Goal::Target::Mapper
  extend self

  def to_entity(record)
    return if record.nil?

    Core::Goal::Target.new(
      id: record.id,
      kind: record.kind,
      name: record.name,
      color: record.color,
      value: record.value
    )
  end

  def to_entities(records)
    records.map { |record| to_entity(record) }
  end
end
