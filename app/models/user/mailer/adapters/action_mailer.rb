class User::Mailer::Adapters::ActionMailer
  include Core::User::Mailer::Interface

  def deliver_confirmation(email:, token:)
    UserMailer.with(email:, token:).email_verification.deliver_later
  end

  def deliver_password_reset(email:, token:)
    UserMailer.with(email:, token:).password_reset.deliver_later
  end
end
