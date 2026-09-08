require "rails_helper"

RSpec.describe UserMailer, type: :mailer do
  around do |example|
    previous = ENV["FRONTEND_URL"]
    ENV["FRONTEND_URL"] = "http://frontend.test/"
    example.run
  ensure
    ENV["FRONTEND_URL"] = previous
  end

  it "builds the password reset email using the frontend url" do
    mail = described_class.with(email: "jane@example.com", token: "reset-token").password_reset

    expect(mail.to).to eq([ "jane@example.com" ])
    expect(mail.body.encoded).to include("http://frontend.test/users/password/edit?token=reset-token")
  end

  it "builds the email verification email using the frontend url" do
    mail = described_class.with(email: "jane@example.com", token: "confirm-token").email_verification

    expect(mail.to).to eq([ "jane@example.com" ])
    expect(mail.body.encoded).to include("http://frontend.test/users/confirmation?token=confirm-token")
  end
end
