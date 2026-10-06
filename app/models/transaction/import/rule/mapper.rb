module Transaction::Import::Rule::Mapper
  extend self

  def to_entity(record)
    return if record.nil?

    Core::Transaction::Import::Rule::Entity.new(
      id: record.id,
      user_id: record.user_id,
      name: record.name,
      position: record.position,
      active: record.active,
      match_type: record.match_type,
      pattern: record.pattern,
      case_sensitive: record.case_sensitive,
      target_column: record.target_column,
      effects: Transaction::Import::Rule::Effect::Mapper.to_entities(record.effects)
    )
  end

  def to_entities(records)
    records.map { |record| to_entity(record) }
  end

  def to_record(entity)
    Transaction::Import::Rule::Record.find(entity.id)
  end

  def to_errors(record)
    Core::Errors.new(record.errors.messages)
  end
end
