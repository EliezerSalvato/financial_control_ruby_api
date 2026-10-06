module Core::Transaction::Import::SourceKey
  def self.build(date:, description:, amount:, occurrence: 1)
    key = "#{date.iso8601}|#{description}|#{format('%.2f', amount)}"

    occurrence > 1 ? "#{key}|#{occurrence}" : key
  end

  # Identical lines in the same file are told apart by their occurrence number.
  def self.raw_key(date:, description:, amount:)
    "#{date}|#{description.to_s.squish}|#{amount}"
  end
end
