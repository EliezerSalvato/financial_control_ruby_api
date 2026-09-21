FactoryBot.define do
  factory :tag, class: "Tag::Record" do
    user
    sequence(:name) { |n| "Tag #{n}" }
    color { "#3B82F6" }

    trait :inactive do
      active { false }
    end

    trait :with_goal do
      transient do
        goal_starts_on { Date.new(2026, 1, 15) }
        goal_value { 500 }
      end

      after(:create) do |tag, evaluator|
        create(:tag_goal, tag:, starts_on: evaluator.goal_starts_on, value: evaluator.goal_value)
      end
    end
  end

  factory :tag_goal, class: "Tag::Goal::Record" do
    transient do
      starts_on { Date.new(2026, 1, 15) }
    end

    tag
    month { starts_on.month }
    year { starts_on.year }
    value { 500 }
  end
end
