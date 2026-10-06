module Transaction::Import::Rule::Effect::Mapper
  extend self

  def to_entity(record)
    return if record.nil?

    Core::Transaction::Import::Rule::Effect::Entity.new(
      id: record.id,
      position: record.position,
      effect_type: record.effect_type,
      target_column: record.target_column,
      category_id: record.category_id,
      tag_ids: record.tag_ids,
      recurrence_type: record.recurrence_type,
      match_type: record.match_type,
      pattern: record.pattern,
      replacement: record.replacement,
      installments_count: record.installments_count
    )
  end

  def to_entities(records)
    records.map { |record| to_entity(record) }
  end
end
