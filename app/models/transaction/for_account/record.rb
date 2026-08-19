class Transaction::ForAccount::Record < ApplicationRecord
  self.table_name = "transaction_for_accounts"

  has_paper_trail

  belongs_to :financial_transaction, class_name: "Transaction::Record", foreign_key: :transaction_id, inverse_of: :for_account
  belongs_to :account, class_name: "Account::Record"
end
