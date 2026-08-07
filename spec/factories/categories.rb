FactoryBot.define do
  factory :category, class: "Category::Record" do
    user
    sequence(:name) { |n| "Category #{n}" }
    color { "#3B82F6" }

    trait :inactive do
      active { false }
    end
  end
end
