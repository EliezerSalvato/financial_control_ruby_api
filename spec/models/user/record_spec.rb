require "rails_helper"

RSpec.describe User::Record, type: :model do
  include ActiveSupport::Testing::TimeHelpers

  subject(:user) { create(:user) }

  describe "associations" do
    it "has the expected dependent associations" do
      expect(described_class.reflect_on_association(:sessions).options)
        .to include(class_name: "User::Session::Record", foreign_key: :user_id, dependent: :destroy)
      expect(described_class.reflect_on_association(:email_confirmations).options)
        .to include(class_name: "User::Email::Confirmation::Record", foreign_key: :user_id, dependent: :destroy)
      expect(described_class.reflect_on_association(:password_resets).options)
        .to include(class_name: "User::Password::Reset::Record", foreign_key: :user_id, dependent: :destroy)
    end

    it "destroys associated records with the user" do
      session = User::Session::Record.create!(
        user: user,
        refresh_token_digest: "session-token",
        refresh_token_expires_at: 1.day.from_now
      )
      confirmation = User::Email::Confirmation::Record.create!(
        user: user,
        token_digest: "confirmation-token",
        expires_at: 1.day.from_now
      )
      password_reset = User::Password::Reset::Record.create!(
        user: user,
        token_digest: "reset-token",
        expires_at: 1.day.from_now
      )

      user.destroy!

      expect(User::Session::Record.exists?(session.id)).to be(false)
      expect(User::Email::Confirmation::Record.exists?(confirmation.id)).to be(false)
      expect(User::Password::Reset::Record.exists?(password_reset.id)).to be(false)
    end
  end

  describe "paper trail" do
    it "does not store password_digest on create" do
      version = user.versions.find_by!(event: "create")

      expect(version.object_changes.keys).not_to include("password_digest")
      expect(Array(version.object&.keys)).not_to include("password_digest")
    end

    it "does not store password_digest when other attributes change" do
      user.update!(first_name: "Updated")
      version = user.versions.where(event: "update").last

      expect(version.object.keys).not_to include("password_digest")
      expect(version.object_changes.keys).not_to include("password_digest")
    end

    it "does not store password_digest when the password changes" do
      user.update!(password: "new-password123", password_confirmation: "new-password123")

      user.versions.find_each do |version|
        expect(Array(version.object&.keys)).not_to include("password_digest")
        expect(Array(version.object_changes&.keys)).not_to include("password_digest")
      end
    end
  end

  describe "password authentication" do
    it "stores a password digest and authenticates the correct password" do
      expect(user.password_digest).to be_present
      expect(user.authenticate("password123")).to eq(user)
    end

    it "rejects an incorrect password" do
      expect(user.authenticate("incorrect-password")).to be(false)
    end
  end

  describe "reset password token" do
    it "finds the user from a valid token" do
      token = user.generate_token_for(:reset_password)

      expect(described_class.find_by_token_for(:reset_password, token)).to eq(user)
    end

    it "invalidates the token when the password changes" do
      token = user.generate_token_for(:reset_password)

      user.update!(password: "new-password123", password_confirmation: "new-password123")

      expect(described_class.find_by_token_for(:reset_password, token)).to be_nil
    end

    it "expires the token after the configured duration" do
      token = user.generate_token_for(:reset_password)

      travel Core::User::Password::RESET_TOKEN_EXPIRES_IN + 1.second

      expect(described_class.find_by_token_for(:reset_password, token)).to be_nil
    end
  end

  describe "email confirmation token" do
    it "finds the user from a valid token" do
      token = user.generate_token_for(:email_confirmation)

      expect(described_class.find_by_token_for(:email_confirmation, token)).to eq(user)
    end

    it "invalidates the token when the email changes" do
      token = user.generate_token_for(:email_confirmation)

      user.update!(email: "new-email@example.com")

      expect(described_class.find_by_token_for(:email_confirmation, token)).to be_nil
    end

    it "invalidates the token when the verification status changes" do
      token = user.generate_token_for(:email_confirmation)

      user.update!(verified: true)

      expect(described_class.find_by_token_for(:email_confirmation, token)).to be_nil
    end

    it "expires the token after the configured duration" do
      token = user.generate_token_for(:email_confirmation)

      travel Core::User::Email::CONFIRMATION_TOKEN_EXPIRES_IN + 1.second

      expect(described_class.find_by_token_for(:email_confirmation, token)).to be_nil
    end
  end
end
