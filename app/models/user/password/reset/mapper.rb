module User::Password::Reset::Mapper
  extend self

  def to_entity(record)
    return if record.nil?

    Core::User::Password::Reset::Entity.new(
      id: record.id,
      user_id: record.user_id,
      expires_at: record.expires_at,
      reset_at: record.reset_at
    )
  end

  def to_record(entity)
    User::Password::Reset::Record.find(entity.id)
  end

  def to_errors(record)
    Core::Errors.new(record.errors.messages)
  end
end
