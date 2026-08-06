require "rails_helper"

RSpec.describe User::Password::Reset::Record, type: :model do
  include ActiveSupport::Testing::TimeHelpers

  subject(:password_reset) { create(:user_password_reset) }

  describe "associations" do
    it "belongs to a user" do
      expect(described_class.reflect_on_association(:user).options)
        .to include(class_name: "User::Record")
      expect(password_reset.user).to be_a(User::Record)
    end
  end

  describe ".not_reset" do
    it "includes resets without reset_at" do
      pending_reset = create(:user_password_reset)
      create(:user_password_reset, :reset)

      expect(described_class.not_reset).to contain_exactly(pending_reset)
    end
  end

  describe ".not_expired" do
    it "includes resets whose expires_at is in the future" do
      active_reset = create(:user_password_reset, expires_at: 1.hour.from_now)
      create(:user_password_reset, :expired)

      expect(described_class.not_expired).to contain_exactly(active_reset)
    end

    it "includes resets that expire exactly now" do
      freeze_time do
        borderline_reset = create(:user_password_reset, expires_at: Time.current)
        create(:user_password_reset, expires_at: 1.second.ago)

        expect(described_class.not_expired).to contain_exactly(borderline_reset)
      end
    end
  end

  describe ".pending" do
    it "includes only unused and not expired resets" do
      pending_reset = create(:user_password_reset)
      create(:user_password_reset, :reset)
      create(:user_password_reset, :expired)
      create(:user_password_reset, :reset, :expired)

      expect(described_class.pending).to contain_exactly(pending_reset)
    end
  end
end
