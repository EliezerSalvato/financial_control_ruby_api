require "rails_helper"

RSpec.describe Transaction::Recurrence::Record, type: :model do
  it "computes month and year from starts_on" do
    recurrence = create(:transaction_recurrence, starts_on: Date.new(2026, 8, 11))

    expect(recurrence.month).to eq(8)
    expect(recurrence.year).to eq(2026)
  end

  it "treats month and year as readonly generated columns" do
    expect(described_class.readonly_attributes).to include("month", "year")
  end

  it "enforces uniqueness of transaction_id, month and year" do
    transaction = create(:transaction, with_links: false)
    create(:transaction_recurrence, financial_transaction: transaction, starts_on: Date.new(2026, 8, 1))

    duplicate = Transaction::Recurrence::Record.new(
      financial_transaction: transaction,
      starts_on: Date.new(2026, 8, 15),
      value: 50
    )

    expect { duplicate.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end
end
