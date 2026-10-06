FactoryBot.define do
  factory :transaction_import_rule, class: "Transaction::Import::Rule::Record" do
    user
    sequence(:name) { |n| "Rule #{n}" }
    sequence(:position)
    match_type { "contains" }
    pattern { "Pattern" }

    trait :regex do
      match_type { "regex" }
    end

    trait :inactive do
      active { false }
    end

    transient do
      effects_attributes { [] }
    end

    after(:build) do |rule, evaluator|
      evaluator.effects_attributes.each_with_index do |attributes, position|
        rule.effects << build(:transaction_import_rule_effect, import_rule: rule, position:, **attributes)
      end
    end
  end

  factory :transaction_import_rule_effect, class: "Transaction::Import::Rule::Effect::Record" do
    association :import_rule, factory: :transaction_import_rule
    position { 0 }
    effect_type { "replace_text" }
    pattern { "Pattern" if effect_type == "replace_text" }
    replacement { "" if effect_type == "replace_text" }
  end
end
