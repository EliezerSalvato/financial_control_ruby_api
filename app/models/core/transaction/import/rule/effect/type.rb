module Core::Transaction::Import::Rule::Effect::Type
  SET_CATEGORY = "set_category"
  ADD_TAGS = "add_tags"
  SET_RECURRENCE_TYPE = "set_recurrence_type"
  REPLACE_TEXT = "replace_text"
  SET_INSTALLMENTS_COUNT = "set_installments_count"
  SKIP = "skip"

  ALL = [ SET_CATEGORY, ADD_TAGS, SET_RECURRENCE_TYPE, REPLACE_TEXT, SET_INSTALLMENTS_COUNT, SKIP ].freeze
end
