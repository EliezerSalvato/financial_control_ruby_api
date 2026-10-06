Core::Transaction::Import::Rule::Effect::Entity = Data.define(
  :id,
  :position,
  :effect_type,
  :target_column,
  :category_id,
  :tag_ids,
  :recurrence_type,
  :match_type,
  :pattern,
  :replacement,
  :installments_count
) do
  def initialize(
    id: nil,
    position: 0,
    effect_type:,
    target_column: Core::Transaction::Import::Rule::TargetColumn::BOTH,
    category_id: nil,
    tag_ids: [],
    recurrence_type: nil,
    match_type: Core::Transaction::Import::Rule::MatchType::CONTAINS,
    pattern: nil,
    replacement: nil,
    installments_count: nil
  )
    super
  end

  # Extracts the installments count from `text` with the first capture group of `pattern`.
  def extract_installments_count(text)
    count = regex.match(text)&.captures&.first.to_i

    count if count > 1
  rescue Regexp::TimeoutError
    nil
  end

  # Effect patterns are always case-insensitive.
  def regex
    Core::Transaction::Import::Rule::Pattern.compile(match_type:, pattern:, case_sensitive: false)
  end
end
