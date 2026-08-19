class Transaction::ForTransferBetweenAccounts::Record < ApplicationRecord
  self.table_name = "transaction_for_transfer_between_accounts"

  has_paper_trail

  belongs_to :financial_transaction, class_name: "Transaction::Record", foreign_key: :transaction_id, inverse_of: :for_transfer_between_accounts
  belongs_to :source_account, class_name: "Account::Record"
  belongs_to :destination_account, class_name: "Account::Record"
end
