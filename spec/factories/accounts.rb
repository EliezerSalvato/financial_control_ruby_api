FactoryBot.define do
  factory :account, class: "Account::Record" do
    user
    sequence(:name) { |n| "Account #{n}" }
    kind { "cash" }
    color { "#3B82F6" }
    current_balance { 0 }
    bank_account_type { nil }
    institution { nil }

    trait :bank_account do
      kind { "bank_account" }
      bank_account_type { "checking" }
      institution { association :institution, user: }
    end

    trait :inactive do
      active { false }
    end
  end
end
