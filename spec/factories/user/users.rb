FactoryBot.define do
  factory :user, class: "User::Record" do
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "password123" }
    password_confirmation { password }

    trait :verified do
      verified { true }
    end

    trait :inactive do
      active { false }
    end
  end
end
