require "rails_helper"

RSpec.describe Transaction::Import::Rule::Record, type: :model do
  it "applies the database defaults" do
    rule = create(:transaction_import_rule)

    expect(rule).to have_attributes(active: true, case_sensitive: false, match_type: "contains", target_column: "both", effects: [])
  end

  it "validates the match type and the target column" do
    expect(build(:transaction_import_rule, match_type: "glob")).not_to be_valid
    expect(build(:transaction_import_rule, target_column: "amount")).not_to be_valid
  end

  it "exposes the ransackable attributes and no associations" do
    expect(described_class.ransackable_attributes).to contain_exactly("name", "active", "match_type", "target_column", "position")
    expect(described_class.ransackable_associations).to eq([])
  end

  it "enforces unique names per user, ignoring the case" do
    user = create(:user)
    create(:transaction_import_rule, user:, name: "Delivery")

    expect { create(:transaction_import_rule, user:, name: "DELIVERY") }.to raise_error(ActiveRecord::RecordNotUnique)
    expect { create(:transaction_import_rule, name: "Delivery") }.not_to raise_error
  end

  it "orders the effects by position and destroys them with the rule" do
    rule = create(
      :transaction_import_rule,
      effects_attributes: [ { effect_type: "replace_text", pattern: "x" }, { effect_type: "set_category", category_id: create(:category).id } ]
    )
    rule.effects.last.update!(position: 0)
    rule.effects.first.update!(position: 1)

    expect(rule.reload.effects.map(&:effect_type)).to eq(%w[set_category replace_text])
    expect { rule.destroy }.to change(Transaction::Import::Rule::Effect::Record, :count).by(-2)
  end
end
