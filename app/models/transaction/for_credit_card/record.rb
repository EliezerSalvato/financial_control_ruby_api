class Transaction::ForCreditCard::Record < ApplicationRecord
  self.table_name = "transaction_for_credit_cards"

  has_paper_trail

  belongs_to :financial_transaction, class_name: "Transaction::Record", foreign_key: :transaction_id, inverse_of: :for_credit_card
  belongs_to :credit_card, class_name: "CreditCard::Record"

  enum :limit_consumption_type, {
    upfront: "upfront",
    monthly: "monthly"
  }, validate: { allow_nil: true }
end
