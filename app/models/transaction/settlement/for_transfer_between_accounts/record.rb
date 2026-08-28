class Transaction::Settlement::ForTransferBetweenAccounts::Record < ApplicationRecord
  self.table_name = "transaction_settlement_for_transfer_between_accounts"

  has_paper_trail

  belongs_to :transaction_settlement, class_name: "Transaction::Settlement::Record", inverse_of: :for_transfer_between_accounts
  belongs_to :source_account, class_name: "Account::Record"
  belongs_to :destination_account, class_name: "Account::Record"
end
