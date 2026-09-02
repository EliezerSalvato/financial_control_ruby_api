module Notification::Broadcast
  extend self

  def stream_target(user_id) = user_id

  def created(notification)
    publish(
      user_id: notification.user_id,
      kind: notification.kind,
      notification: Notification::Serializer.new(notification).serializable_hash.fetch(:data)
    )
  end

  def batch_created(user_id:, kind:)
    publish(user_id:, kind:)
  end

  private

  def publish(user_id:, kind:, notification: nil)
    payload = { kind:, unread_count: Notification::Adapters.repository.unread_count(user_id:) }
    payload[:notification] = notification if notification

    NotificationChannel.broadcast_to(stream_target(user_id), payload)
  end
end
