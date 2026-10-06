module Core::Transaction::Import::Rule::Applying
  EffectType = Core::Transaction::Import::Rule::Effect::Type

  def self.call(row:, rules:)
    state = {
      description: row[:description],
      category_name: row[:category_name].presence,
      category_id: nil,
      recurrence_type: row[:recurrence_type].presence,
      installments_count: nil,
      tag_names: Array(row[:tag_names]),
      tag_ids: [],
      skipped: false
    }
    source_column = row[:source_column] || Core::Transaction::Import::Rule::TargetColumn::DESCRIPTION
    applied_rules = []

    rules.each do |rule|
      next unless rule.applies_to?(source_column)
      next unless matches?(rule, state[:description])

      applied_rules << { id: rule.id, name: rule.name }
      rule.effects.sort_by(&:position).each { |effect| apply_effect(state, effect, source_column, row[:description]) }

      break if state[:skipped]
    end

    row.merge(state).merge(applied_rules:)
  end

  # A rule whose regex times out is ignored.
  def self.matches?(rule, description)
    rule.regex.match?(description)
  rescue Regexp::TimeoutError
    false
  end
  private_class_method :matches?

  def self.apply_effect(state, effect, source_column, original_description)
    case effect.effect_type
    when EffectType::SET_CATEGORY then state[:category_id] ||= effect.category_id if state[:category_name].blank?
    when EffectType::SKIP then state[:skipped] = true
    when EffectType::SET_RECURRENCE_TYPE then state[:recurrence_type] ||= effect.recurrence_type
    when EffectType::SET_INSTALLMENTS_COUNT then set_installments_count(state, effect, source_column, original_description)
    when EffectType::ADD_TAGS then state[:tag_ids] = (state[:tag_ids] + effect.tag_ids).uniq
    else replace_text(state, effect, source_column)
    end
  end
  private_class_method :apply_effect

  # Reads the count from the original text, so it does not depend on earlier replace_text effects.
  def self.set_installments_count(state, effect, source_column, original_description)
    return unless Core::Transaction::Import::Rule::TargetColumn.applies?(effect.target_column, source_column)

    state[:installments_count] ||= effect.installments_count || effect.extract_installments_count(original_description)
  end
  private_class_method :set_installments_count

  def self.replace_text(state, effect, source_column)
    return unless Core::Transaction::Import::Rule::TargetColumn.applies?(effect.target_column, source_column)

    # Keeps the current description when the change would leave nothing behind.
    state[:description] = state[:description].gsub(effect.regex) { effect.replacement.to_s }.squish.presence || state[:description]
  rescue Regexp::TimeoutError
    nil
  end
  private_class_method :replace_text
end
