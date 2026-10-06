class CreateTransactionImportRuleEffects < ActiveRecord::Migration[8.1]
  def change
    create_enum :transaction_import_rule_effect_type, %w[set_category add_tags set_recurrence_type replace_text set_installments_count skip]

    create_table :transaction_import_rule_effects, id: :uuid do |t|
      t.references :import_rule, null: false, foreign_key: { to_table: :transaction_import_rules, on_delete: :cascade }, type: :uuid, index: false
      t.integer :position, null: false, default: 0
      t.enum :effect_type, enum_type: :transaction_import_rule_effect_type, null: false
      t.enum :target_column, enum_type: :transaction_import_rule_target_column, null: false, default: "both"
      t.references :category, foreign_key: { on_delete: :nullify }, type: :uuid
      t.uuid :tag_ids, array: true, null: false, default: []
      t.enum :recurrence_type, enum_type: :transaction_recurrence_type
      t.enum :match_type, enum_type: :transaction_import_rule_match_type, null: false, default: "contains"
      t.string :pattern
      t.string :replacement
      t.integer :installments_count

      t.timestamps

      t.check_constraint "effect_type = 'set_category' OR category_id IS NULL",
                         name: "transaction_import_rule_effects_category_only_for_set_category"
      t.check_constraint "(effect_type = 'add_tags' AND cardinality(tag_ids) > 0) OR (effect_type <> 'add_tags' AND cardinality(tag_ids) = 0)",
                         name: "transaction_import_rule_effects_tag_ids_only_for_add_tags"
      t.check_constraint "(effect_type = 'set_recurrence_type') = (recurrence_type IS NOT NULL)",
                         name: "transaction_import_rule_effects_recurrence_only_for_set_recurrence"
      t.check_constraint "(effect_type = 'replace_text' AND pattern IS NOT NULL AND replacement IS NOT NULL) OR " \
                         "(effect_type = 'set_installments_count' AND replacement IS NULL AND match_type = 'regex') OR " \
                         "(effect_type NOT IN ('replace_text', 'set_installments_count') AND pattern IS NULL AND replacement IS NULL " \
                         "AND target_column = 'both' AND match_type = 'contains')",
                         name: "tir_effects_text_fields_by_effect_type"
      t.check_constraint "(effect_type = 'set_installments_count' AND " \
                         "((installments_count > 1 AND pattern IS NULL) OR (installments_count IS NULL AND pattern IS NOT NULL))) OR " \
                         "(effect_type <> 'set_installments_count' AND installments_count IS NULL)",
                         name: "tir_effects_installments_count_by_effect_type"
    end

    add_index :transaction_import_rule_effects, %i[import_rule_id position]
  end
end
