require "rails_helper"

RSpec.describe Core::Settlement::ReferenceDate do
  def monthly_status(month:, year:)
    Core::MonthlyStatus::Entity.new(
      id: SecureRandom.uuid,
      user_id: SecureRandom.uuid,
      month:,
      year:,
      status: Core::MonthlyStatus::Status::OPEN,
      processing: false,
      last_processed_at: nil
    )
  end

  describe ".for" do
    it "returns yesterday for the current month" do
      today = Date.new(2026, 8, 15)

      expect(described_class.for(monthly_status: monthly_status(month: 8, year: 2026), today:)).to eq(Date.new(2026, 8, 14))
    end

    it "returns nil for the current month on day 1" do
      today = Date.new(2026, 8, 1)

      expect(described_class.for(monthly_status: monthly_status(month: 8, year: 2026), today:)).to be_nil
    end

    it "returns the last day of a previous month" do
      today = Date.new(2026, 8, 15)

      expect(described_class.for(monthly_status: monthly_status(month: 7, year: 2026), today:)).to eq(Date.new(2026, 7, 31))
    end

    it "returns nil for a future month" do
      today = Date.new(2026, 8, 15)

      expect(described_class.for(monthly_status: monthly_status(month: 9, year: 2026), today:)).to be_nil
    end
  end
end
