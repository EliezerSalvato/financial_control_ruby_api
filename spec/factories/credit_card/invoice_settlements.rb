FactoryBot.define do
  factory :credit_card_invoice_settlement, class: "CreditCard::InvoiceSettlement::Record" do
    credit_card
    payment_account { credit_card.default_payment_account }
    opening_date { Date.new(2026, 7, 11) }
    closing_date { Date.new(2026, 8, 10) }
    due_date { Date.new(2026, 8, 17) }
    total_value { 100 }
    released_limit { 0 }
    settled_on { Date.new(2026, 8, 17) }
  end
end
