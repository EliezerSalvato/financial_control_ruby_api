module Notification
  extend Solid::Context

  self.actions = {
    list: Core::Notification::Listing,
    find: Core::Notification::Finding,
    create: Core::Notification::Creation,
    create_all: Core::Notification::BatchCreation,
    mark_as_read: Core::Notification::MarkAsRead,
    mark_all_as_read: Core::Notification::MarkAllAsRead
  }
end
