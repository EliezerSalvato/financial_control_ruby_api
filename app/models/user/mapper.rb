module User::Mapper
  extend self

  def to_entity(record)
    return if record.nil?

    Core::User::Entity.new(
      id: record.id,
      first_name: record.first_name,
      last_name: record.last_name,
      email: record.email,
      verified: record.verified,
      active: record.active,
      configs: record.configs.to_h
    )
  end

  def to_record(entity)
    User::Record.find(entity.id)
  end

  def to_errors(record)
    Core::Errors.new(record.errors.messages)
  end
end
