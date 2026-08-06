FactoryBot.define do
  factory :user_password_reset, class: "User::Password::Reset::Record" do
    transient do
      token { nil }
    end

    user
    sequence(:token_digest) { |n| "password-reset-token-digest-#{n}" }
    expires_at { 1.day.from_now }

    after(:build) do |password_reset, evaluator|
      next if evaluator.token.blank?

      password_reset.token_digest = User::Adapters.token.digest(evaluator.token)
    end

    trait :reset do
      reset_at { Time.current }
    end

    trait :expired do
      expires_at { 1.hour.ago }
    end
  end
end
