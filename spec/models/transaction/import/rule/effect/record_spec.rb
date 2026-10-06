require "rails_helper"

RSpec.describe Transaction::Import::Rule::Effect::Record, type: :model do
  it "applies the database defaults" do
    effect = create(:transaction_import_rule_effect, effect_type: "set_recurrence_type", recurrence_type: "recurring", pattern: nil, replacement: nil)

    expect(effect).to have_attributes(target_column: "both", match_type: "contains", tag_ids: [], category_id: nil, pattern: nil, replacement: nil)
  end

  it "nullifies the category when it is deleted" do
    category = create(:category)
    effect = create(:transaction_import_rule_effect, effect_type: "set_category", category_id: category.id)

    category.destroy

    expect(effect.reload.category_id).to be_nil
  end

  it "validates the effect type, target column, match type and recurrence type" do
    expect(build(:transaction_import_rule_effect, effect_type: "remove_match")).not_to be_valid
    expect(build(:transaction_import_rule_effect, match_type: "glob")).not_to be_valid
    expect(build(:transaction_import_rule_effect, effect_type: "explode")).not_to be_valid
    expect(build(:transaction_import_rule_effect, target_column: "amount")).not_to be_valid
    expect(build(:transaction_import_rule_effect, recurrence_type: "weekly")).not_to be_valid
    expect(build(:transaction_import_rule_effect, effect_type: "set_recurrence_type", recurrence_type: "recurring")).to be_valid
  end

  it "enforces the fields of each effect type in the database" do
    no_text = { pattern: nil, replacement: nil }
    invalid = [
      { effect_type: "add_tags", **no_text },
      { effect_type: "set_recurrence_type", **no_text },
      { effect_type: "skip", tag_ids: [ SecureRandom.uuid_v7 ], **no_text },
      { effect_type: "set_recurrence_type", recurrence_type: "recurring", target_column: "title", **no_text },
      { effect_type: "set_recurrence_type", recurrence_type: "recurring", pattern: "x", replacement: nil },
      { pattern: nil },
      { replacement: nil },
      { tag_ids: [ SecureRandom.uuid_v7 ] },
      { category_id: create(:category).id },
      { recurrence_type: "recurring" }
    ]

    rule = create(:transaction_import_rule)

    invalid.each do |attributes|
      expect { build(:transaction_import_rule_effect, import_rule: rule, **attributes).save!(validate: false) }.to raise_error(ActiveRecord::CheckViolation)
    end
  end
end
