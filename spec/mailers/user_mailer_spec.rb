require "rails_helper"

RSpec.describe UserMailer, type: :mailer do
  around do |example|
    previous_frontend = ENV["FRONTEND_URL"]
    previous_from = ENV["MAIL_FROM"]
    ENV["FRONTEND_URL"] = "http://frontend.test/"
    ENV["MAIL_FROM"] = "from@example.com"
    example.run
  ensure
    ENV["FRONTEND_URL"] = previous_frontend
    ENV["MAIL_FROM"] = previous_from
  end

  it "builds the password reset email using the frontend url" do
    mail = described_class.with(email: "jane@example.com", token: "reset-token").password_reset

    expect(mail.to).to eq([ "jane@example.com" ])
    expect(mail.from).to eq([ "from@example.com" ])
    expect(mail.body.encoded).to include("http://frontend.test/users/password/edit?token=reset-token")
  end

  it "builds the email verification email using the frontend url" do
    mail = described_class.with(email: "jane@example.com", token: "confirm-token").email_verification

    expect(mail.to).to eq([ "jane@example.com" ])
    expect(mail.from).to eq([ "from@example.com" ])
    expect(mail.body.encoded).to include("http://frontend.test/users/confirmation?token=confirm-token")
  end

  it "prefers ENV FRONTEND_URL and MAIL_FROM over credentials" do
    allow(Rails.application.credentials).to receive(:[]).and_call_original
    allow(Rails.application.credentials).to receive(:[]).with(:frontend_url).and_return("https://from-credentials.example")
    allow(Rails.application.credentials).to receive(:dig).and_call_original
    allow(Rails.application.credentials).to receive(:dig).with(:mail, :from).and_return("credentials@example.com")

    mail = described_class.with(email: "jane@example.com", token: "reset-token").password_reset

    expect(mail.from).to eq([ "from@example.com" ])
    expect(mail.body.encoded).to include("http://frontend.test/users/password/edit?token=reset-token")
  end

  it "falls back to credentials when ENV is blank" do
    ENV.delete("FRONTEND_URL")
    ENV.delete("MAIL_FROM")

    allow(Rails.application.credentials).to receive(:[]).and_call_original
    allow(Rails.application.credentials).to receive(:[]).with(:frontend_url).and_return("https://vue.example.test")
    allow(Rails.application.credentials).to receive(:dig).and_call_original
    allow(Rails.application.credentials).to receive(:dig).with(:mail, :from).and_return("no-reply@example.test")

    mail = described_class.with(email: "jane@example.com", token: "reset-token").password_reset

    expect(mail.from).to eq([ "no-reply@example.test" ])
    expect(mail.body.encoded).to include("https://vue.example.test/users/password/edit?token=reset-token")
  end
end
