module Goal::Mapper
  extend self

  def to_entity(record)
    return if record.nil?

    Core::Goal::Transaction.new(
      id: record.id,
      kind: record.kind,
      description: record.description,
      recurrence_type: record.recurrence_type,
      value: record.value,
      first_recurrence_on: record.first_recurrence_on,
      current_recurrence_on: record.current_recurrence_on,
      ends_on: record.ends_on,
      category_id: record.category_id,
      tag_ids: record.tag_ids || []
    )
  end

  def to_entities(records)
    records.map { |record| to_entity(record) }
  end
end
