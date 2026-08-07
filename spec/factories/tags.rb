FactoryBot.define do
  factory :tag, class: "Tag::Record" do
    user
    sequence(:name) { |n| "Tag #{n}" }
    color { "#3B82F6" }

    trait :inactive do
      active { false }
    end
  end
end
