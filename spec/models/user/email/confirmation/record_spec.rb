require "rails_helper"

RSpec.describe User::Email::Confirmation::Record, type: :model do
  include ActiveSupport::Testing::TimeHelpers

  subject(:confirmation) { create(:user_email_confirmation) }

  describe "associations" do
    it "belongs to a user" do
      expect(described_class.reflect_on_association(:user).options)
        .to include(class_name: "User::Record")
      expect(confirmation.user).to be_a(User::Record)
    end
  end

  describe ".not_confirmed" do
    it "includes confirmations without confirmed_at" do
      pending_confirmation = create(:user_email_confirmation)
      create(:user_email_confirmation, :confirmed)

      expect(described_class.not_confirmed).to contain_exactly(pending_confirmation)
    end
  end

  describe ".not_expired" do
    it "includes confirmations whose expires_at is in the future" do
      active_confirmation = create(:user_email_confirmation, expires_at: 1.hour.from_now)
      create(:user_email_confirmation, :expired)

      expect(described_class.not_expired).to contain_exactly(active_confirmation)
    end

    it "includes confirmations that expire exactly now" do
      freeze_time do
        borderline_confirmation = create(:user_email_confirmation, expires_at: Time.current)
        create(:user_email_confirmation, expires_at: 1.second.ago)

        expect(described_class.not_expired).to contain_exactly(borderline_confirmation)
      end
    end
  end

  describe ".pending" do
    it "includes only unconfirmed and not expired confirmations" do
      pending_confirmation = create(:user_email_confirmation)
      create(:user_email_confirmation, :confirmed)
      create(:user_email_confirmation, :expired)
      create(:user_email_confirmation, :confirmed, :expired)

      expect(described_class.pending).to contain_exactly(pending_confirmation)
    end
  end
end
