class CreateTransactionForCreditCards < ActiveRecord::Migration[8.1]
  def change
    create_enum :transaction_limit_consumption_type, %w[upfront monthly]

    create_table :transaction_for_credit_cards, id: :uuid do |t|
      t.references :transaction, null: false, foreign_key: true, type: :uuid, index: { unique: true }
      t.references :credit_card, null: false, foreign_key: true, type: :uuid, index: true
      t.enum :limit_consumption_type, enum_type: :transaction_limit_consumption_type, null: true

      t.timestamps
    end
  end
end
