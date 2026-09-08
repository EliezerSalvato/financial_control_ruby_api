require "rails_helper"

RSpec.describe Core::Transaction::Settlement::Occurrence do
  it "holds the occurrence identity" do
    transaction_id = UUID.generate
    occurred_on = Date.new(2026, 8, 11)

    occurrence = described_class.new(transaction_id:, occurred_on:, value: BigDecimal("10"))

    expect(occurrence).to have_attributes(transaction_id:, occurred_on:, value: BigDecimal("10"))
  end
end
