class Core::Notification::BatchCreation < ApplicationSolidProcess
  deps do
    attribute :notification_creation, default: -> { Core::Notification::Creation }
  end

  input do
    attribute :user_id, :string
    attribute :notifications, default: -> { [] }
    attribute :broadcast_kind, :string

    validates :user_id, presence: true
    validates :broadcast_kind, presence: true
    validates :notifications, kind_of: Array
  end

  def call(attributes)
    rollback_on_failure {
      Given(attributes)
        .and_then(:create_notifications)
    }
      .and_then(:broadcast_batch_created)
  end

  private

  def create_notifications(user_id:, notifications:, **)
    created = []

    notifications.each do |item|
      result = deps.notification_creation.call(**item.to_h.symbolize_keys, user_id:, broadcast: false)

      case result
      in Solid::Success(notification:)
        created << notification
      else
        return with_nested_process(result, persist_failure: :notifications_creation_failed)
      end
    end

    Continue(notifications: created)
  end

  def broadcast_batch_created(user_id:, notifications:, broadcast_kind:, **)
    return Success(:no_notifications_created, notifications:) if notifications.empty?

    Notification::Broadcast.batch_created(user_id:, kind: broadcast_kind)

    Success(:notifications_created, notifications:)
  end
end
