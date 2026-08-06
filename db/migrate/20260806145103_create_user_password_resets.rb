class CreateUserPasswordResets < ActiveRecord::Migration[8.1]
  def change
    create_table :user_password_resets, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid, index: true
      t.string :token_digest, null: false, index: { unique: true }
      t.datetime :expires_at, null: false
      t.datetime :reset_at

      t.timestamps
    end
  end
end
