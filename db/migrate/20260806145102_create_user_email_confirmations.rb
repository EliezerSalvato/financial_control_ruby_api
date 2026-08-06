class CreateUserEmailConfirmations < ActiveRecord::Migration[8.1]
  def change
    create_table :user_email_confirmations, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid, index: true
      t.string :old_email
      t.string :new_email
      t.string :token_digest, null: false, index: { unique: true }
      t.datetime :expires_at, null: false
      t.datetime :confirmed_at

      t.timestamps
    end
  end
end
