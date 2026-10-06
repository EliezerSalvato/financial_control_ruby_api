module Transaction::Import::Rule::Effect::Serializer
  def self.call(effect)
    {
      id: effect.id,
      position: effect.position,
      effect_type: effect.effect_type,
      target_column: effect.target_column,
      category_id: effect.category_id,
      tag_ids: effect.tag_ids,
      recurrence_type: effect.recurrence_type,
      match_type: effect.match_type,
      pattern: effect.pattern,
      replacement: effect.replacement,
      installments_count: effect.installments_count
    }
  end
end
