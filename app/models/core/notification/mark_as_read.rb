class Core::Notification::MarkAsRead < ApplicationSolidProcess
  deps do
    attribute :notification_repository, default: -> { Notification::Adapters.repository }

    validates :notification_repository, kind_of: Core::Notification::Repository::Interface
  end

  input do
    attribute :user_id, :string
    attribute :id, :string

    validates :user_id, :id, presence: true
  end

  def call(attributes)
    Given(attributes)
      .and_then(:load_notification)
      .and_then(:mark_as_read)
  end

  private

  def load_notification(user_id:, id:, **)
    case deps.notification_repository.find_by_id(user_id:, id:)
    in Solid::Success(notification:) then Continue(notification:)
    in Solid::Failure(type: :notification_not_found)
      input.errors.add(:base, :notification_not_found)
      Failure(:notification_not_found)
    end
  end

  def mark_as_read(notification:, **)
    return Continue(notification:) if notification.read?

    case deps.notification_repository.mark_as_read(notification:, read_at: Time.current)
    in Solid::Success(notification:) then Continue(notification:)
    in Solid::Failure(errors:)
      add_errors_to_input(errors)
      input.errors.add(:base, :notification_mark_as_read_failed)

      Failure(:notification_mark_as_read_failed, input:)
    end
  end
end
