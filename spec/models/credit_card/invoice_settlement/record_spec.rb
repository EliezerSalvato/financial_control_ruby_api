require "rails_helper"

RSpec.describe CreditCard::InvoiceSettlement::Record, type: :model do
  it "enforces uniqueness of credit_card_id and due_date" do
    invoice = create(:credit_card_invoice_settlement, due_date: Date.new(2026, 8, 17))

    duplicate = CreditCard::InvoiceSettlement::Record.new(
      credit_card: invoice.credit_card,
      payment_account: invoice.payment_account,
      opening_date: Date.new(2026, 7, 11),
      closing_date: Date.new(2026, 8, 10),
      due_date: Date.new(2026, 8, 17),
      total_value: 50,
      settled_on: Date.new(2026, 8, 17)
    )

    expect { duplicate.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end
end
