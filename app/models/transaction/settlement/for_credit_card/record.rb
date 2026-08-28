class Transaction::Settlement::ForCreditCard::Record < ApplicationRecord
  self.table_name = "transaction_settlement_for_credit_cards"

  has_paper_trail

  belongs_to :transaction_settlement, class_name: "Transaction::Settlement::Record", inverse_of: :for_credit_card
  belongs_to :credit_card_invoice_settlement, class_name: "CreditCard::InvoiceSettlement::Record", optional: true
end
