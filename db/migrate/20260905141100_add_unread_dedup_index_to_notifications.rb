class AddUnreadDedupIndexToNotifications < ActiveRecord::Migration[8.1]
  def change
    add_column :notifications, :dedup_key, :jsonb

    add_index :notifications,
              [ :user_id, :kind, :notifiable_type, :notifiable_id, :dedup_key ],
              unique: true,
              where: "read = false AND dedup_key IS NOT NULL",
              nulls_not_distinct: true,
              name: "index_notifications_on_unread_dedup"
  end
end
