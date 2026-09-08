class CreditCard::InvoiceSettlement::Serializer
  include JSONAPI::Serializer

  set_type :credit_card_invoice_settlement
  attributes :id,
             :credit_card_id,
             :payment_account_id,
             :opening_date,
             :closing_date,
             :due_date,
             :total_value,
             :released_limit,
             :settled_on
end
