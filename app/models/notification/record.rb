class Notification::Record < ApplicationRecord
  self.table_name = "notifications"

  belongs_to :user, class_name: "User::Record"
  belongs_to :notifiable, polymorphic: true, optional: true

  after_create_commit :broadcast_created, if: :broadcast?

  private

  def broadcast_created
    Notification::Broadcast.created(Notification::Mapper.to_entity(self))
  end
end
