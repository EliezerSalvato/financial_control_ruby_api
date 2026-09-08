FactoryBot.define do
  factory :notification, class: "Notification::Record" do
    user
    kind { "system" }
    sequence(:title) { |n| "Notification #{n}" }
    body { "Notification body" }
    read { false }
    read_at { nil }
    broadcast { true }
    data { {} }

    trait :read do
      read { true }
      read_at { Time.current }
    end

    trait :silent do
      broadcast { false }
    end

    trait :with_notifiable do
      notifiable_type { "Transaction" }
      notifiable_id { UUID.generate }
    end
  end
end
