class CreateCreditCards < ActiveRecord::Migration[8.1]
  def change
    create_table :credit_cards, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid, index: true
      t.references :institution, null: false, foreign_key: true, type: :uuid, index: true
      t.references :default_payment_account, null: false, foreign_key: { to_table: :accounts }, type: :uuid, index: true
      t.string :name, null: false
      t.decimal :total_limit, precision: 15, scale: 2, null: false, default: 0
      t.decimal :available_limit, precision: 15, scale: 2, null: false, default: 0
      t.integer :closing_day, null: false
      t.integer :due_day, null: false
      t.string :network, null: false
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :credit_cards, "user_id, LOWER(name)", unique: true, name: "index_credit_cards_on_user_id_and_lower_name"
    add_index :credit_cards, %i[user_id active]

    add_check_constraint :credit_cards, "closing_day BETWEEN 1 AND 31", name: "credit_cards_closing_day_range"
    add_check_constraint :credit_cards, "due_day BETWEEN 1 AND 31", name: "credit_cards_due_day_range"
    add_check_constraint :credit_cards, "total_limit >= 0", name: "credit_cards_total_limit_non_negative"
    add_check_constraint :credit_cards, "available_limit BETWEEN 0 AND total_limit", name: "credit_cards_available_limit_within_total"
  end
end
