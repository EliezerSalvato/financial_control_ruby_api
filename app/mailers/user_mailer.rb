class UserMailer < ApplicationMailer
  def password_reset
    mail to: params[:email], subject: t("mailer.user.password_reset.subject")
  end

  def email_verification
    mail to: params[:email], subject: t("mailer.user.email.confirmation.subject")
  end
end
