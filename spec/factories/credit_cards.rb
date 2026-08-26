FactoryBot.define do
  factory :credit_card, class: "CreditCard::Record" do
    user
    institution { association :institution, user: }
    default_payment_account { association :account, :bank_account, user: }
    sequence(:name) { |n| "Credit Card #{n}" }
    total_limit { 5000 }
    available_limit { 5000 }
    closing_day { 10 }
    due_day { 17 }
    network { "mastercard" }

    trait :inactive do
      active { false }
    end

    trait :allow_negative_available_limit do
      allow_negative_available_limit { true }
    end
  end
end
