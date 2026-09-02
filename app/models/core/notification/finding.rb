class Core::Notification::Finding < ApplicationSolidProcess
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
      .and_then(:find_notification)
  end

  private

  def find_notification(user_id:, id:, **)
    case deps.notification_repository.find_by_id(user_id:, id:)
    in Solid::Success(notification:) then Continue(notification:)
    in Solid::Failure(type: :notification_not_found) then Failure(:notification_not_found)
    end
  end
end
