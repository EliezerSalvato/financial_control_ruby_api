require "rails_helper"

RSpec.describe Transaction::Settlement::Record, type: :model do
  it "enforces uniqueness of transaction_id and occurred_on" do
    settlement = create(:transaction_settlement, occurred_on: Date.new(2026, 8, 11))

    duplicate = Transaction::Settlement::Record.new(
      financial_transaction: settlement.financial_transaction,
      occurred_on: Date.new(2026, 8, 11),
      settled_on: Date.new(2026, 8, 12),
      value: 50
    )

    expect { duplicate.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "rejects a negative value" do
    expect {
      create(:transaction_settlement, value: -1)
    }.to raise_error(ActiveRecord::StatementInvalid)
  end

  it "rejects an installment_number below 1" do
    expect {
      create(:transaction_settlement, installment_number: 0)
    }.to raise_error(ActiveRecord::StatementInvalid)
  end
end
