class Transaction::Import::Rule::Serializer
  include JSONAPI::Serializer

  set_type :transaction_import_rule
  attributes :id,
             :name,
             :position,
             :active,
             :match_type,
             :pattern,
             :case_sensitive,
             :target_column

  attribute :effects do |rule|
    rule.effects.map { |effect| Transaction::Import::Rule::Effect::Serializer.call(effect) }
  end
end
