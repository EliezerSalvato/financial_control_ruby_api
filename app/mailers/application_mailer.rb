class ApplicationMailer < ActionMailer::Base
  default from: -> { mail_from }
  layout "mailer"

  helper_method :frontend_url

  private

  def frontend_url
    (ENV["FRONTEND_URL"].presence || Rails.application.credentials[:frontend_url]).to_s.chomp("/")
  end

  def mail_from
    ENV["MAIL_FROM"].presence || Rails.application.credentials.dig(:mail, :from)
  end
end
