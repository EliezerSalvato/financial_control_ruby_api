Core::CreditCard::InvoiceSettlement::Entity = Data.define(
  :id,
  :credit_card_id,
  :payment_account_id,
  :opening_date,
  :closing_date,
  :due_date,
  :total_value,
  :released_limit,
  :settled_on
)
