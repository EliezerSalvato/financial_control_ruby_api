module Tag::Mapper
  extend self

  def to_entity(record)
    return if record.nil?

    Core::Tag::Entity.new(
      id: record.id,
      user_id: record.user_id,
      name: record.name,
      color: record.color,
      active: record.active,
      goal_ends_on: record.goal_ends_on,
      goals: Array(record.goals).sort_by { |goal| [ goal.year, goal.month ] }.map { |goal| Tag::Goal::Mapper.to_entity(goal) }
    )
  end

  def to_entities(records)
    records.map { |record| to_entity(record) }
  end

  def to_record(entity)
    Tag::Record.find(entity.id)
  end

  def to_errors(record)
    Core::Errors.new(record.errors.messages)
  end
end
