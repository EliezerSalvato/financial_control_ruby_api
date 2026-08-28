class Transaction::Settlement::Record < ApplicationRecord
  self.table_name = "transaction_settlements"

  has_paper_trail

  belongs_to :financial_transaction, class_name: "Transaction::Record", foreign_key: :transaction_id, inverse_of: :settlements
  has_one :for_account,
          class_name: "Transaction::Settlement::ForAccount::Record",
          foreign_key: :transaction_settlement_id,
          dependent: :destroy,
          inverse_of: :transaction_settlement
  has_one :for_transfer_between_accounts,
          class_name: "Transaction::Settlement::ForTransferBetweenAccounts::Record",
          foreign_key: :transaction_settlement_id,
          dependent: :destroy,
          inverse_of: :transaction_settlement
  has_one :for_credit_card,
          class_name: "Transaction::Settlement::ForCreditCard::Record",
          foreign_key: :transaction_settlement_id,
          dependent: :destroy,
          inverse_of: :transaction_settlement
end
