FactoryBot.define do
  factory :institution, class: "Institution::Record" do
    user
    sequence(:name) { |n| "Institution #{n}" }
    logo_key { "institutions/default.png" }

    trait :inactive do
      active { false }
    end
  end
end
