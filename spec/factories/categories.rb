FactoryBot.define do
  factory :category, class: "Category::Record" do
    user
    sequence(:name) { |n| "Category #{n}" }
    color { "#3B82F6" }

    trait :inactive do
      active { false }
    end

    trait :with_goal do
      transient do
        goal_starts_on { Date.new(2026, 1, 15) }
        goal_value { 500 }
      end

      after(:create) do |category, evaluator|
        create(:category_goal, category:, starts_on: evaluator.goal_starts_on, value: evaluator.goal_value)
      end
    end
  end

  factory :category_goal, class: "Category::Goal::Record" do
    transient do
      starts_on { Date.new(2026, 1, 15) }
    end

    category
    month { starts_on.month }
    year { starts_on.year }
    value { 500 }
  end
end
