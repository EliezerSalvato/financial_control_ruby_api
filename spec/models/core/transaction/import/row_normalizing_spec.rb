require "rails_helper"

RSpec.describe Core::Transaction::Import::RowNormalizing do
  let(:attributes) { { date: "2026-10-01", description: "  Ifd*Burger   King ", amount: "25,90" } }

  def normalize(overrides = {}) = described_class.call(**attributes, **overrides)

  it "normalizes the row" do
    result = normalize(category: " Food ", tags: "delivery|Fun; delivery, ", recurrence_type: "installment", ends_on: "2027-01-01")

    expect(result.value[:row]).to eq(
      date: Date.new(2026, 10, 1), description: "Ifd*Burger King", original_description: "Ifd*Burger King",
      source_column: "description", amount: BigDecimal("25.90"), ends_on: Date.new(2027, 1, 1), recurrence_type: "installment",
      category_name: "Food", tag_names: %w[delivery Fun]
    )
  end

  it "keeps the column the text came from" do
    expect(normalize(source_column: " title ").value[:row][:source_column]).to eq("title")
    expect(normalize(source_column: " ").value[:row][:source_column]).to eq("description")
    expect(normalize(source_column: "amount")).to be_failure(:invalid_input)
  end

  it "returns empty optional values" do
    expect(normalize.value[:row]).to include(ends_on: nil, recurrence_type: nil, category_name: nil, tag_names: [])
  end

  {
    "100.01" => "100.01", "100,01" => "100.01", "1.234,56" => "1234.56", "1,234.56" => "1234.56",
    "-25,90" => "25.90", "+10" => "10", "R$ 1.234,56" => "1234.56", "1.234" => "1234", "0,5" => "0.5", "7" => "7"
  }.each do |raw, expected|
    it "parses the amount #{raw.inspect}" do
      expect(normalize(amount: raw).value[:row][:amount]).to eq(BigDecimal(expected))
    end
  end

  [ "abc", "", "1.2.3", "12,345,6", "1,23,456", "1e5" ].each do |raw|
    it "rejects the amount #{raw.inspect}" do
      result = normalize(amount: raw)

      expect(result).to be_failure(:invalid_input)
      expect(result.value[:input].errors.details[:amount].pluck(:error)).to eq([ :invalid_amount ])
    end
  end

  { "01/10/2026" => "2026-10-01", "1/2/2026" => "2026-02-01", "01/10/26" => "2026-10-01" }.each do |raw, expected|
    it "parses the Brazilian date #{raw.inspect}" do
      expect(normalize(date: raw).value[:row][:date]).to eq(Date.iso8601(expected))
    end
  end

  [ "2026-13-01", "2026-02-30", "26-10-01", "32/10/2026", "01/13/2026", "", nil ].each do |raw|
    it "rejects the date #{raw.inspect}" do
      result = normalize(date: raw)

      expect(result).to be_failure(:invalid_input)
      expect(result.value[:input].errors.details[:date].pluck(:error)).to eq([ :invalid_date ])
    end
  end

  it "rejects an invalid ends_on" do
    expect(normalize(ends_on: "next year").value[:input].errors.details[:ends_on].pluck(:error)).to eq([ :invalid_date ])
  end

  it "rejects an unknown recurrence type" do
    expect(normalize(recurrence_type: "weekly")).to be_failure(:invalid_input)
  end

  it "requires a description" do
    expect(normalize(description: "   ")).to be_failure(:invalid_input)
  end
end
