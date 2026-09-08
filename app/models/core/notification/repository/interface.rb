module Core::Notification::Repository::Interface
  include Solid::Adapters::Interface

  module Methods
    def list(user_id:, after:, limit:, unread: false)
      UUID.valid?(user_id) => true
      after => String | NilClass
      limit => Integer
      unread => TrueClass | FalseClass

      super.tap do
        _1 => (
          Solid::Failure(:invalid_cursor, {}) |
          Solid::Success(:notifications_listed, { notifications: Array, pagination: Core::Pagination::Cursor::Entity })
        )
      end
    end

    def find_by_id(user_id:, id:)
      UUID.valid?(user_id) => true
      UUID.valid?(id) => true

      super.tap do
        _1 => (
          Solid::Failure(:notification_not_found, {}) |
          Solid::Success(:notification_found, { notification: Core::Notification::Entity })
        )
      end
    end

    def create(attributes:)
      attributes => Hash

      super.tap do
        _1 => (
          Solid::Failure(:notification_creation_failed, { errors: Core::Errors }) |
          Solid::Success(:notification_created, { notification: Core::Notification::Entity }) |
          Solid::Success(:notification_skipped, {})
        )
      end
    end

    def mark_as_read(notification:, read_at:)
      notification => Core::Notification::Entity
      read_at => ActiveSupport::TimeWithZone | Time

      super.tap do
        _1 => (
          Solid::Failure(:notification_mark_as_read_failed, { errors: Core::Errors }) |
          Solid::Success(:notification_marked_as_read, { notification: Core::Notification::Entity })
        )
      end
    end

    def mark_all_as_read(user_id:, read_at:)
      UUID.valid?(user_id) => true
      read_at => ActiveSupport::TimeWithZone | Time

      super.tap do
        _1 => Solid::Success(:notifications_marked_as_read, { count: Integer })
      end
    end

    def unread_count(user_id:)
      UUID.valid?(user_id) => true

      super.tap do
        _1 => Integer
      end
    end

    def exists_unread?(user_id:, kind:, notifiable_type: nil, notifiable_id: nil, data: {})
      UUID.valid?(user_id) => true
      kind => String
      notifiable_type => String | NilClass
      notifiable_id.nil? || UUID.valid?(notifiable_id) => true
      data => Hash

      super.tap do
        _1 => (true | false)
      end
    end
  end
end
