class CreateCreditCardInvoiceSettlements < ActiveRecord::Migration[8.1]
  def change
    create_table :credit_card_invoice_settlements, id: :uuid do |t|
      t.references :credit_card, null: false, foreign_key: true, type: :uuid, index: false
      t.references :payment_account, null: false, foreign_key: { to_table: :accounts }, type: :uuid, index: true
      t.date :opening_date, null: false
      t.date :closing_date, null: false
      t.date :due_date, null: false
      t.decimal :total_value, precision: 15, scale: 2, null: false
      t.decimal :released_limit, precision: 15, scale: 2, null: false, default: 0
      t.date :settled_on, null: false

      t.timestamps
    end

    add_index :credit_card_invoice_settlements, %i[credit_card_id due_date], unique: true
    add_check_constraint :credit_card_invoice_settlements, "total_value >= 0",
                         name: "credit_card_invoice_settlements_total_value_non_negative"
    add_check_constraint :credit_card_invoice_settlements, "released_limit >= 0",
                         name: "credit_card_invoice_settlements_released_limit_non_negative"
  end
end
