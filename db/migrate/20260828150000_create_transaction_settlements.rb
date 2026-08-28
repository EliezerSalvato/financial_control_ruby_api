class CreateTransactionSettlements < ActiveRecord::Migration[8.1]
  def change
    create_table :transaction_settlements, id: :uuid do |t|
      t.references :transaction, null: false, foreign_key: true, type: :uuid, index: false
      t.date :occurred_on, null: false
      t.date :settled_on, null: false
      t.decimal :value, precision: 15, scale: 2, null: false
      t.integer :installment_number

      t.timestamps
    end

    add_index :transaction_settlements, %i[transaction_id occurred_on], unique: true
    add_check_constraint :transaction_settlements, "value >= 0", name: "transaction_settlements_value_non_negative"
    add_check_constraint :transaction_settlements, "installment_number IS NULL OR installment_number >= 1",
                         name: "transaction_settlements_installment_number_positive"
  end
end
