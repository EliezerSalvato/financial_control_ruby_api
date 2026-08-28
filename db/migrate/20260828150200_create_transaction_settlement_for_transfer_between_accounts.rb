class CreateTransactionSettlementForTransferBetweenAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :transaction_settlement_for_transfer_between_accounts, id: :uuid do |t|
      t.references :transaction_settlement, null: false, foreign_key: true, type: :uuid, index: { unique: true }
      t.references :source_account, null: false, foreign_key: { to_table: :accounts }, type: :uuid, index: true
      t.references :destination_account, null: false, foreign_key: { to_table: :accounts }, type: :uuid, index: true

      t.timestamps
    end

    add_check_constraint :transaction_settlement_for_transfer_between_accounts,
                         "source_account_id <> destination_account_id",
                         name: "transaction_settlement_for_transfer_between_accounts_distinct_accounts"
  end
end
