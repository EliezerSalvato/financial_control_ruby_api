class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users, id: :uuid do |t|
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :email, null: false, index: { unique: true }
      t.string :password_digest, null: false
      t.boolean :verified, null: false, default: false
      t.boolean :active, null: false, default: true, index: true

      t.timestamps
    end
  end
end
