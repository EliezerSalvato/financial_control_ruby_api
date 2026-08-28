class CreateTransactionSettlementForCreditCards < ActiveRecord::Migration[8.1]
  def change
    create_table :transaction_settlement_for_credit_cards, id: :uuid do |t|
      t.references :transaction_settlement, null: false, foreign_key: true, type: :uuid, index: { unique: true }
      t.decimal :limit_consumed, precision: 15, scale: 2, null: false
      t.references :credit_card_invoice_settlement, null: true, foreign_key: true, type: :uuid, index: true

      t.timestamps
    end

    add_check_constraint :transaction_settlement_for_credit_cards, "limit_consumed >= 0",
                         name: "transaction_settlement_for_credit_cards_limit_consumed_non_negative"
  end
end
