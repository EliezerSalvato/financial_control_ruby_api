class Core::Transaction::Import::RowNormalizing < ApplicationSolidProcess
  DATE_FORMAT = /\A\d{4}-\d{2}-\d{2}\z/
  BR_DATE_FORMAT = %r{\A(\d{1,2})/(\d{1,2})/(\d{2}|\d{4})\z}
  PLAIN_AMOUNT = /\A\d+(?:[.,]\d{1,2})?\z/
  PT_BR_AMOUNT = /\A\d{1,3}(?:\.\d{3})+(?:,\d{1,2})?\z/
  EN_AMOUNT = /\A\d{1,3}(?:,\d{3})+(?:\.\d{1,2})?\z/
  TAG_SEPARATOR = /[|;,]/

  input do
    attribute :date, :string
    attribute :description, :string
    attribute :source_column, :string, default: Core::Transaction::Import::Rule::TargetColumn::DESCRIPTION
    attribute :amount, :string
    attribute :category, :string
    attribute :tags, :string
    attribute :recurrence_type, :string
    attribute :ends_on, :string

    normalizes :date, :amount, :category, :recurrence_type, :ends_on, with: ->(value) { value&.strip.presence }
    normalizes :source_column, with: ->(value) { value.strip.presence || Core::Transaction::Import::Rule::TargetColumn::DESCRIPTION }
    normalizes :description, with: ->(value) { value&.squish.presence }
    normalizes :tags, with: ->(value) { value&.strip.presence }

    validates :description, presence: true
    validates :source_column, inclusion: { in: [ Core::Transaction::Import::Rule::TargetColumn::TITLE, Core::Transaction::Import::Rule::TargetColumn::DESCRIPTION ] }
    validates :recurrence_type, inclusion: { in: Core::Transaction::RecurrenceType::ALL }, allow_nil: true
  end

  def call(attributes)
    Given(attributes)
      .and_then(:parse_date)
      .and_then(:parse_amount)
      .and_then(:parse_ends_on)
      .and_then(:build_row)
  end

  private

  def parse_date(date:, **)
    parsed = parse_iso_date(date)
    input.errors.add(:date, :invalid_date) if parsed.nil?

    return Failure(:invalid_input, input:) if input.errors.any?

    Continue(date: parsed)
  end

  def parse_amount(amount:, **)
    parsed = parse_money(amount)
    input.errors.add(:amount, :invalid_amount) if parsed.nil?

    return Failure(:invalid_input, input:) if input.errors.any?

    Continue(amount: parsed)
  end

  def parse_ends_on(ends_on:, **)
    return Continue(ends_on: nil) if ends_on.nil?

    parsed = parse_iso_date(ends_on)
    input.errors.add(:ends_on, :invalid_date) if parsed.nil?

    return Failure(:invalid_input, input:) if input.errors.any?

    Continue(ends_on: parsed)
  end

  def build_row(date:, description:, source_column:, amount:, category:, tags:, recurrence_type:, ends_on:, **)
    Continue(
      row: {
        date:,
        description:,
        original_description: description,
        source_column:,
        amount:,
        ends_on:,
        recurrence_type:,
        category_name: category,
        tag_names: tags.to_s.split(TAG_SEPARATOR).map(&:strip).reject(&:blank?).uniq(&:downcase)
      }
    )
  end

  def parse_iso_date(value)
    return unless value

    if (match = value.match(BR_DATE_FORMAT))
      day, month, year = match.captures
      year = "20#{year}" if year.size == 2

      return Date.new(year.to_i, month.to_i, day.to_i)
    end

    Date.iso8601(value) if value.match?(DATE_FORMAT)
  rescue Date::Error
    nil
  end

  # The sign is ignored: the transaction kind comes from the import form.
  def parse_money(value)
    return if value.blank?

    cleaned = value.strip.sub(/\A[-+]?\s*(?:R\$|\$)?\s*[-+]?/i, "")

    case cleaned
    when PLAIN_AMOUNT then BigDecimal(cleaned.tr(",", "."))
    when PT_BR_AMOUNT then BigDecimal(cleaned.delete(".").tr(",", "."))
    when EN_AMOUNT then BigDecimal(cleaned.delete(","))
    end
  end
end
