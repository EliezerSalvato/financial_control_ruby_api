class CreditCard::InvoiceSettlement::Record < ApplicationRecord
  self.table_name = "credit_card_invoice_settlements"

  has_paper_trail

  belongs_to :credit_card, class_name: "CreditCard::Record"
  belongs_to :payment_account, class_name: "Account::Record"
end
