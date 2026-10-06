module Core::Transaction::Import::Rule::TargetColumn
  TITLE = "title"
  DESCRIPTION = "description"
  BOTH = "both"

  ALL = [ TITLE, DESCRIPTION, BOTH ].freeze

  # Whether a rule (or effect) aimed at `target` runs for a CSV whose text column is `source`.
  def self.applies?(target, source)
    target == BOTH || target == source
  end
end
