# Normalizes and validates the effects sent with an import rule. The order of the list is the effect position.
module Core::Transaction::Import::Rule::Effect::Attributes
  Type = Core::Transaction::Import::Rule::Effect::Type
  TargetColumn = Core::Transaction::Import::Rule::TargetColumn
  MatchType = Core::Transaction::Import::Rule::MatchType

  # What a serialized effect carries for fields that do not apply to its type, so editing can resend what a read returned.
  DEFAULTS = { target_column: TargetColumn::BOTH, match_type: MatchType::CONTAINS }.freeze

  RELEVANT_ATTRIBUTES = {
    Type::SET_CATEGORY => %i[category_id],
    Type::ADD_TAGS => %i[tag_ids],
    Type::SET_RECURRENCE_TYPE => %i[recurrence_type],
    Type::REPLACE_TEXT => %i[target_column match_type pattern replacement],
    Type::SET_INSTALLMENTS_COUNT => %i[target_column match_type pattern installments_count],
    Type::SKIP => []
  }.freeze

  # Keeps only what matters for each effect type, so stale fields never reach the database.
  def self.normalize(effects)
    return if effects.nil?

    Array(effects).map.with_index do |effect, position|
      attributes = effect.respond_to?(:to_h) ? effect.to_h.symbolize_keys : {}
      effect_type = attributes[:effect_type].to_s.strip.presence

      allowed = RELEVANT_ATTRIBUTES.fetch(effect_type, [])
      relevant = clean(attributes.slice(*allowed))
      unexpected = unexpected_fields(attributes, effect_type, allowed)

      {
        position:,
        effect_type:,
        target_column: TargetColumn::BOTH,
        category_id: nil,
        tag_ids: [],
        recurrence_type: nil,
        match_type: MatchType::CONTAINS,
        pattern: nil,
        replacement: nil,
        installments_count: nil
      }.merge(relevant.compact.except(:tag_ids), relevant.slice(:tag_ids), forced_attributes(effect_type), unexpected.any? ? { unexpected_fields: unexpected } : {})
    end
  end

  # The pattern of `set_installments_count` is always a regular expression, whatever `match_type` was sent.
  def self.forced_attributes(effect_type)
    effect_type == Type::SET_INSTALLMENTS_COUNT ? { match_type: MatchType::REGEX } : {}
  end
  private_class_method :forced_attributes

  # Fields filled in (beyond their defaults) that do not belong to the effect type. Only known types are checked: an unknown type is already invalid.
  def self.unexpected_fields(attributes, effect_type, allowed)
    return [] unless Type::ALL.include?(effect_type)

    (RELEVANT_ATTRIBUTES.values.flatten.uniq - allowed).select do |name|
      attributes[name].present? && attributes[name] != DEFAULTS[name]
    end
  end
  private_class_method :unexpected_fields

  def self.clean(attributes)
    attributes.to_h do |name, value|
      cleaned =
        case name
        when :tag_ids then Array(value).map { |id| id.to_s.strip.presence }.compact.uniq
        when :pattern then value&.to_s.presence
        when :replacement then value&.to_s
        when :installments_count then value&.to_s&.strip.presence
        else value&.to_s&.strip.presence
        end

      [ name, cleaned ]
    end
  end
  private_class_method :clean

  def self.validate(errors, effects)
    return errors.add(:effects, :blank) if effects&.empty?

    effects&.each do |effect|
      invalid_fields(effect).each do |field|
        errors.add(:effects, :invalid_effect, position: effect[:position] + 1, field:)
      end

      effect.fetch(:unexpected_fields, []).each do |field|
        errors.add(:effects, :unexpected_effect_field, position: effect[:position] + 1, field:)
      end
    end
  end

  def self.invalid_fields(effect)
    type = effect[:effect_type]
    return [ :effect_type ] unless Type::ALL.include?(type)

    [
      (:category_id if type == Type::SET_CATEGORY && !valid_uuid?(effect[:category_id])),
      (:tag_ids if type == Type::ADD_TAGS && !valid_tag_ids?(effect[:tag_ids])),
      (:recurrence_type if type == Type::SET_RECURRENCE_TYPE && Core::Transaction::RecurrenceType::ALL.exclude?(effect[:recurrence_type])),
      (:replacement if type == Type::REPLACE_TEXT && effect[:replacement].nil?),
      (:target_column if TargetColumn::ALL.exclude?(effect[:target_column])),
      (:match_type if MatchType::ALL.exclude?(effect[:match_type])),
      (:pattern if type == Type::REPLACE_TEXT && !valid_pattern?(effect))
    ].compact + installments_count_invalid_fields(effect)
  end
  private_class_method :invalid_fields

  # `set_installments_count` takes either a fixed `installments_count` or a regex `pattern` whose first group captures it.
  def self.installments_count_invalid_fields(effect)
    return [] unless effect[:effect_type] == Type::SET_INSTALLMENTS_COUNT

    count = effect[:installments_count]
    pattern = effect[:pattern]

    return [ :installments_count ] if count.nil? == pattern.nil?
    return [ :installments_count ] if count && !(count.match?(/\A\d+\z/) && count.to_i > 1)
    return [ :pattern ] if pattern && !Core::Transaction::Import::Rule::Pattern.valid_with_capture_group?(pattern)

    []
  end
  private_class_method :installments_count_invalid_fields

  def self.valid_uuid?(value)
    value.is_a?(String) && UUID.valid?(value)
  end
  private_class_method :valid_uuid?

  def self.valid_tag_ids?(ids)
    ids.any? && ids.all? { |id| valid_uuid?(id) }
  end
  private_class_method :valid_tag_ids?

  def self.valid_pattern?(effect)
    effect[:pattern].present? && Core::Transaction::Import::Rule::Pattern.valid?(match_type: effect[:match_type], pattern: effect[:pattern])
  end
  private_class_method :valid_pattern?
end
