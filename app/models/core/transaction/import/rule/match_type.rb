module Core::Transaction::Import::Rule::MatchType
  CONTAINS = "contains"
  REGEX = "regex"

  ALL = [ CONTAINS, REGEX ].freeze
end
