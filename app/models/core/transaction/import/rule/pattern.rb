module Core::Transaction::Import::Rule::Pattern
  REGEX_TIMEOUT = 0.1

  def self.compile(match_type:, pattern:, case_sensitive:)
    source = match_type == Core::Transaction::Import::Rule::MatchType::REGEX ? pattern : Regexp.escape(pattern)
    options = case_sensitive ? 0 : Regexp::IGNORECASE

    Regexp.new(source, options, timeout: REGEX_TIMEOUT)
  end

  def self.valid?(match_type:, pattern:)
    return true if pattern.blank? || match_type != Core::Transaction::Import::Rule::MatchType::REGEX

    compile(match_type:, pattern:, case_sensitive: true)
    true
  rescue RegexpError
    false
  end

  # A regex that captures something in its first group, such as `parcela \d+/(\d+)`.
  def self.valid_with_capture_group?(pattern)
    regex = Regexp.new("(?:#{pattern})|", timeout: REGEX_TIMEOUT)

    regex.match("").size > 1
  rescue RegexpError
    false
  end

  def self.validate(errors, match_type:, pattern:)
    errors.add(:pattern, :invalid_regex) unless valid?(match_type:, pattern:)
  end
end
