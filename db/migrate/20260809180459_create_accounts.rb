class CreateAccounts < ActiveRecord::Migration[8.1]
  def change
    create_enum :account_kind, %w[bank_account cash]
    create_enum :bank_account_type, %w[checking savings investment salary]

    create_table :accounts, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid, index: true
      t.references :institution, null: true, foreign_key: true, type: :uuid, index: true
      t.string :name, null: false
      t.enum :kind, enum_type: :account_kind, null: false
      t.enum :bank_account_type, enum_type: :bank_account_type, null: true
      t.decimal :current_balance, precision: 15, scale: 2, null: false, default: 0
      t.string :color, null: false, limit: 9
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :accounts, "user_id, LOWER(name)", unique: true, name: "index_accounts_on_user_id_and_lower_name"
    add_index :accounts, %i[user_id active]

    add_check_constraint :accounts, <<~SQL.squish, name: "accounts_kind_consistency"
      (
        kind = 'bank_account'
        AND bank_account_type IS NOT NULL
        AND institution_id IS NOT NULL
      )
      OR
      (
        kind = 'cash'
        AND bank_account_type IS NULL
        AND institution_id IS NULL
      )
    SQL
  end
end
