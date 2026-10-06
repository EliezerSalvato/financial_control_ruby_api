require "csv"

class Core::Transaction::Import::CsvParsing < ApplicationSolidProcess
  ALIASES = { "value" => "amount" }.freeze
  TEXT_COLUMNS = %w[description title].freeze
  BOM = "﻿".freeze

  input do
    attribute :file, :string

    validates :file, presence: true
  end

  def call(attributes)
    Given(attributes)
      .and_then(:normalize_encoding)
      .and_then(:parse)
      .and_then(:validate_columns)
      .and_then(:validate_row_count)
      .and_then(:build_rows)
  end

  private

  def normalize_encoding(file:, **)
    text = file.dup.force_encoding(Encoding::UTF_8)
    text = file.dup.force_encoding(Encoding::ISO_8859_1).encode(Encoding::UTF_8) unless text.valid_encoding?

    Continue(file: text.delete_prefix(BOM))
  end

  def parse(file:, **)
    table = CSV.parse(file, headers: true, col_sep: separator_for(file), skip_blanks: true, header_converters: ->(header) { normalize_header(header) })

    Continue(table:)
  rescue CSV::MalformedCSVError
    input.errors.add(:file, :invalid_file)
    Failure(:invalid_input, input:)
  end

  def validate_columns(table:, **)
    headers = table.headers.compact
    missing = [ "date", ("title or description" if (TEXT_COLUMNS & headers).empty?), ("amount or value" unless headers.include?("amount")) ].compact - headers

    return Continue() if missing.empty?

    input.errors.add(:file, :missing_columns, columns: missing.join(", "))
    Failure(:invalid_input, input:)
  end

  def validate_row_count(table:, **)
    return Continue() if table.size <= Core::Transaction::Import::MAX_ROWS

    input.errors.add(:file, :too_many_rows, max: Core::Transaction::Import::MAX_ROWS)
    Failure(:invalid_input, input:)
  end

  def build_rows(table:, **)
    source_column = table.headers.include?("description") ? "description" : "title"
    rows = table.map.with_index(1) { |csv_row, number| { row: number, data: csv_row.to_h.compact } }
    rows = rows.reject { |entry| entry[:data].values.all?(&:blank?) }

    Continue(rows: rows.each { |entry| entry[:data] = row_data(entry[:data], source_column) })
  end

  # The text always travels as `description`; `source_column` remembers which CSV column it came from.
  def row_data(data, source_column)
    data = data.except("title").merge("description" => data["title"]).compact if source_column == "title"

    data.merge("source_column" => source_column)
  end

  def separator_for(file)
    header = file.lines.first.to_s

    header.count(";") > header.count(",") ? ";" : ","
  end

  def normalize_header(header)
    name = header.to_s.strip.downcase

    ALIASES.fetch(name, name)
  end
end
