FactoryBot.define do
  factory :monthly_status, class: "MonthlyStatus::Record" do
    user
    month { 8 }
    year { 2026 }
    status { "open" }

    trait :closed do
      status { "closed" }
    end
  end
end
