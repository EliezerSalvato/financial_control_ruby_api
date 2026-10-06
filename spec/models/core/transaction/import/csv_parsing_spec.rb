require "rails_helper"

RSpec.describe Core::Transaction::Import::CsvParsing do
  def parse(content) = described_class.call(file: content)

  it "parses comma separated files and keeps the row numbers" do
    result = parse("date,description,amount,category\n2026-10-01,Coffee,\"1,50\",Food\n2026-10-02,Tea,2.00,\n")

    expect(result).to be_success
    expect(result.value[:rows]).to eq(
      [
        { row: 1, data: { "date" => "2026-10-01", "description" => "Coffee", "amount" => "1,50", "category" => "Food", "source_column" => "description" } },
        { row: 2, data: { "date" => "2026-10-02", "description" => "Tea", "amount" => "2.00", "source_column" => "description" } }
      ]
    )
  end

  it "detects semicolons, strips the BOM and normalizes headers and aliases" do
    result = parse("﻿ Date ;TITLE;Value\n2026-10-01;Market;12,50\n")

    expect(result.value[:rows]).to eq(
      [ { row: 1, data: { "date" => "2026-10-01", "description" => "Market", "amount" => "12,50", "source_column" => "title" } } ]
    )
  end

  it "prefers the description column when the file also has a title" do
    result = parse("date,title,description,amount\n2026-10-01,Ignored,Market,1\n")

    expect(result.value[:rows].first[:data]).to include("description" => "Market", "source_column" => "description")
  end

  it "drops rows without any value" do
    result = parse("date;description;amount\n2026-10-01;Market;1\n;;\n")

    expect(result.value[:rows].map { |entry| entry[:row] }).to eq([ 1 ])
  end

  it "converts latin-1 files to UTF-8" do
    result = parse("date,description,amount\n2026-10-01,Caf\xE9,1\n".b)

    expect(result.value[:rows].first[:data]["description"]).to eq("Café")
  end

  it "fails when required columns are missing" do
    result = parse("date,foo\n2026-10-01,x\n")

    expect(result).to be_failure(:invalid_input)
    expect(result.value[:input].errors.full_messages).to eq([ "File is missing required columns: title or description, amount or value" ])
  end

  it "fails with only a header" do
    expect(parse("date,description\n")).to be_failure(:invalid_input)
  end

  it "fails for blank content" do
    expect(parse("")).to be_failure(:invalid_input)
  end

  it "fails for malformed CSV" do
    expect(parse("date,description,amount\n2026-10-01,\"x,1\n")).to be_failure(:invalid_input)
  end

  it "fails above the row limit" do
    rows = Array.new(Core::Transaction::Import::MAX_ROWS + 1) { "2026-10-01,Coffee,1" }

    expect(parse("date,description,amount\n#{rows.join("\n")}")).to be_failure(:invalid_input)
  end
end
