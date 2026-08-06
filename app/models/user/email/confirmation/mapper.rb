module User::Email::Confirmation::Mapper
  extend self

  def to_entity(record)
    return if record.nil?

    Core::User::Email::Confirmation::Entity.new(
      id: record.id,
      user_id: record.user_id,
      old_email: record.old_email,
      new_email: record.new_email,
      expires_at: record.expires_at,
      confirmed_at: record.confirmed_at
    )
  end

  def to_record(entity)
    User::Email::Confirmation::Record.find(entity.id)
  end

  def to_errors(record)
    Core::Errors.new(record.errors.messages)
  end
end
