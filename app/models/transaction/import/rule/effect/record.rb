class Transaction::Import::Rule::Effect::Record < ApplicationRecord
  self.table_name = "transaction_import_rule_effects"

  belongs_to :import_rule, class_name: "Transaction::Import::Rule::Record", inverse_of: :effects

  enum :effect_type, {
    set_category: "set_category",
    add_tags: "add_tags",
    set_recurrence_type: "set_recurrence_type",
    replace_text: "replace_text",
    set_installments_count: "set_installments_count",
    skip: "skip"
  }, prefix: :effect, validate: true

  enum :target_column, {
    title: "title",
    description: "description",
    both: "both"
  }, prefix: :target, validate: true

  enum :match_type, {
    contains: "contains",
    regex: "regex"
  }, prefix: :match, validate: true

  enum :recurrence_type, {
    one_time: "one_time",
    installment: "installment",
    recurring: "recurring"
  }, validate: { allow_nil: true }
end
