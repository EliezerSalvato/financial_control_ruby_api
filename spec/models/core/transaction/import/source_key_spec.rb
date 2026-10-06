require "rails_helper"

RSpec.describe Core::Transaction::Import::SourceKey do
  let(:date) { Date.new(2026, 10, 1) }

  describe ".build" do
    it "joins date, description and amount" do
      expect(described_class.build(date:, description: "Coffee", amount: BigDecimal("5"))).to eq("2026-10-01|Coffee|5.00")
    end

    it "appends the occurrence from the second identical line on" do
      expect(described_class.build(date:, description: "Café", amount: BigDecimal("5"), occurrence: 1)).to eq("2026-10-01|Café|5.00")
      expect(described_class.build(date:, description: "Café", amount: BigDecimal("5"), occurrence: 2)).to eq("2026-10-01|Café|5.00|2")
    end
  end

  describe ".raw_key" do
    it "ignores extra whitespace in the description" do
      expect(described_class.raw_key(date: "2026-10-01", description: " Coffee   shop ", amount: "5.00"))
        .to eq(described_class.raw_key(date: "2026-10-01", description: "Coffee shop", amount: "5.00"))
    end
  end
end
