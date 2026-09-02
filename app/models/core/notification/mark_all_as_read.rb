class Core::Notification::MarkAllAsRead < ApplicationSolidProcess
  deps do
    attribute :notification_repository, default: -> { Notification::Adapters.repository }

    validates :notification_repository, kind_of: Core::Notification::Repository::Interface
  end

  input do
    attribute :user_id, :string

    validates :user_id, presence: true
  end

  def call(attributes)
    Given(attributes)
      .and_then(:mark_all_as_read)
  end

  private

  def mark_all_as_read(user_id:, **)
    case deps.notification_repository.mark_all_as_read(user_id:, read_at: Time.current)
    in Solid::Success(count:) then Continue(count:)
    else
      input.errors.add(:base, :notifications_mark_as_read_failed)
      Failure(:notifications_mark_as_read_failed, input:)
    end
  end
end
