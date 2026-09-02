class CreateNotifications < ActiveRecord::Migration[8.1]
  def change
    create_table :notifications, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid, index: false

      t.string :kind, null: false

      t.string :title, null: false
      t.text :body

      t.boolean :read, null: false, default: false
      t.datetime :read_at

      t.string :notifiable_type
      t.uuid :notifiable_id

      t.jsonb :data, null: false, default: {}

      t.boolean :broadcast, null: false, default: true

      t.timestamps
    end

    add_index :notifications, [ :user_id, :id ], order: { id: :desc }
    add_index :notifications, :user_id,
              where: "read = false",
              name: "index_notifications_on_user_id_unread"
    add_index :notifications, [ :notifiable_type, :notifiable_id ],
              where: "notifiable_type IS NOT NULL"
  end
end
