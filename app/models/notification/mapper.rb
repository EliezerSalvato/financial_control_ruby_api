module Notification::Mapper
  extend self

  def to_entity(record)
    return if record.nil?

    Core::Notification::Entity.new(
      id: record.id,
      user_id: record.user_id,
      kind: record.kind,
      title: record.title,
      body: record.body,
      read: record.read,
      read_at: record.read_at,
      notifiable_type: record.notifiable_type,
      notifiable_id: record.notifiable_id,
      data: record.data,
      created_at: record.created_at
    )
  end

  def to_entities(records)
    records.map { |record| to_entity(record) }
  end

  def to_record(entity)
    Notification::Record.find(entity.id)
  end

  def to_errors(record)
    Core::Errors.new(record.errors.messages)
  end
end
