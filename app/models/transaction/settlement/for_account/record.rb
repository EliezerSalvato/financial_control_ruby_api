class Transaction::Settlement::ForAccount::Record < ApplicationRecord
  self.table_name = "transaction_settlement_for_accounts"

  has_paper_trail

  belongs_to :transaction_settlement, class_name: "Transaction::Settlement::Record", inverse_of: :for_account
  belongs_to :account, class_name: "Account::Record"
end
