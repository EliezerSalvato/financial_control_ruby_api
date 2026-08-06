class ApplicationMailer < ActionMailer::Base
  default from: "from@example.com"
  layout "mailer"

  helper_method :frontend_url

  private

  def frontend_url
    ENV.fetch("FRONTEND_URL").chomp("/")
  end
end
