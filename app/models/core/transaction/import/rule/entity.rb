Core::Transaction::Import::Rule::Entity = Data.define(
  :id,
  :user_id,
  :name,
  :position,
  :active,
  :match_type,
  :pattern,
  :case_sensitive,
  :target_column,
  :effects
) do
  def initialize(
    id:,
    user_id:,
    name:,
    position:,
    active:,
    match_type:,
    pattern:,
    case_sensitive:,
    target_column: Core::Transaction::Import::Rule::TargetColumn::BOTH,
    effects: []
  )
    super
  end

  def active? = active

  def applies_to?(source_column) = Core::Transaction::Import::Rule::TargetColumn.applies?(target_column, source_column)

  def regex
    Core::Transaction::Import::Rule::Pattern.compile(match_type:, pattern:, case_sensitive:)
  end
end
