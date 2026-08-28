class CreateTransactionSettlementForAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :transaction_settlement_for_accounts, id: :uuid do |t|
      t.references :transaction_settlement, null: false, foreign_key: true, type: :uuid, index: { unique: true }
      t.references :account, null: false, foreign_key: true, type: :uuid, index: true

      t.timestamps
    end
  end
end
