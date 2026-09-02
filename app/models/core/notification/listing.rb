class Core::Notification::Listing < ApplicationSolidProcess
  deps do
    attribute :notification_repository, default: -> { Notification::Adapters.repository }

    validates :notification_repository, kind_of: Core::Notification::Repository::Interface
  end

  input do
    attribute :user_id, :string
    attribute :after, :string
    attribute :limit, :integer, default: Core::Pagination::DEFAULT_PER_PAGE
    attribute :unread, :boolean, default: false

    validates :user_id, presence: true
    validates :limit, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: Core::Pagination::MAX_PER_PAGE }
  end

  def call(attributes)
    Given(attributes)
      .and_then(:list_notifications)
      .and_then(:count_unread)
      .and_expose(:notifications_listed, %i[notifications pagination unread_count])
  end

  private

  def list_notifications(user_id:, after:, limit:, unread:, **)
    case deps.notification_repository.list(user_id:, after:, limit:, unread:)
    in Solid::Success(notifications:, pagination:)
      Continue(notifications:, pagination:)
    in Solid::Failure(type: :invalid_cursor)
      input.errors.add(:after, :invalid)

      Failure(:invalid_cursor, input:)
    end
  end

  def count_unread(user_id:, **)
    Continue(unread_count: deps.notification_repository.unread_count(user_id:))
  end
end
