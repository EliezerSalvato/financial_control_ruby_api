module Notification::Repository::Adapters::ActiveRecord
  include Core::Notification::Repository::Interface
  extend Solid::Output.mixin
  extend self

  def list(user_id:, after:, limit:, unread: false)
    scope = user_notifications(user_id).order(id: :desc)
    scope = scope.where(read: false) if unread
    records, pagination = Pagination.paginate_by_cursor(scope, after:, limit:)

    Success(:notifications_listed, notifications: Notification::Mapper.to_entities(records), pagination:)
  rescue ArgumentError, Pagy::OptionError
    Failure(:invalid_cursor)
  end

  def find_by_id(user_id:, id:)
    notification = user_notifications(user_id).find_by(id:)

    return Success(:notification_found, notification: Notification::Mapper.to_entity(notification)) if notification.present?

    Failure(:notification_not_found)
  end

  def create(attributes:)
    notification = Notification::Record.create(attributes)

    return Success(:notification_created, notification: Notification::Mapper.to_entity(notification)) if notification.persisted?

    Failure(:notification_creation_failed, errors: Notification::Mapper.to_errors(notification))
  end

  def mark_as_read(notification:, read_at:)
    record = Notification::Mapper.to_record(notification)
    updated = record.update(read: true, read_at:)

    return Success(:notification_marked_as_read, notification: Notification::Mapper.to_entity(record)) if updated

    Failure(:notification_mark_as_read_failed, errors: Notification::Mapper.to_errors(record))
  end

  def mark_all_as_read(user_id:, read_at:)
    count = user_notifications(user_id)
              .where(read: false)
              .update_all(read: true, read_at:, updated_at: read_at)

    Success(:notifications_marked_as_read, count:)
  end

  def unread_count(user_id:)
    user_notifications(user_id).where(read: false).count
  end

  private

  def user_notifications(user_id)
    Notification::Record.where(user_id:)
  end
end
