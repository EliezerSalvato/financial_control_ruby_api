FactoryBot.define do
  factory :monthly_status, class: "MonthlyStatus::Record" do
    user
    month { 8 }
    year { 2026 }
    status { "open" }
    processing { false }
    last_processed_at { nil }

    trait :closed do
      status { "closed" }
    end

    trait :processing do
      processing { true }
    end
  end
end
