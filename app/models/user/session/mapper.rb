module User::Session::Mapper
  extend self

  def to_entity(record)
    return if record.nil?

    Core::User::Session::Entity.new(
      id: record.id,
      user_id: record.user_id,
      user_agent: record.user_agent,
      ip_address: record.ip_address,
      refresh_token_expires_at: record.refresh_token_expires_at
    )
  end

  def to_record(entity)
    User::Session::Record.find(entity.id)
  end

  def to_errors(record)
    Core::Errors.new(record.errors.messages)
  end
end
