class NotificationChannel < ApplicationCable::Channel
  def subscribed
    stream_for Notification::Broadcast.stream_target(current_user.id)
  end
end
