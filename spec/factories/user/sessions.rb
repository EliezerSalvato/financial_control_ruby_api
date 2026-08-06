FactoryBot.define do
  factory :user_session, class: "User::Session::Record" do
    transient do
      refresh_token { User::Adapters.token.generate }
    end

    user
    refresh_token_digest { User::Adapters.token.digest(refresh_token) }
    refresh_token_expires_at { 1.day.from_now }
    user_agent { "RSpec" }
    ip_address { "127.0.0.1" }

    trait :expired do
      refresh_token_expires_at { 1.hour.ago }
    end
  end
end
