class CreateTransactionImportRules < ActiveRecord::Migration[8.1]
  def change
    create_enum :transaction_import_rule_match_type, %w[contains regex]
    create_enum :transaction_import_rule_target_column, %w[title description both]

    create_table :transaction_import_rules, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid, index: false
      t.string :name, null: false
      t.integer :position, null: false, default: 0
      t.boolean :active, null: false, default: true
      t.enum :match_type, enum_type: :transaction_import_rule_match_type, null: false, default: "contains"
      t.string :pattern, null: false
      t.boolean :case_sensitive, null: false, default: false
      t.enum :target_column, enum_type: :transaction_import_rule_target_column, null: false, default: "both"

      t.timestamps
    end

    add_index :transaction_import_rules, %i[user_id position]
    add_index :transaction_import_rules, "user_id, lower(name)",
              unique: true,
              name: "index_transaction_import_rules_on_user_id_and_lower_name"
  end
end
