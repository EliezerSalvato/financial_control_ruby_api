class CreateUserSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :user_sessions, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid, index: true
      t.string :user_agent
      t.string :ip_address
      t.string :refresh_token_digest, null: false, index: { unique: true }
      t.datetime :refresh_token_expires_at, null: false

      t.timestamps
    end
  end
end
