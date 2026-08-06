module Core::User::Email
  FORMAT = URI::MailTo::EMAIL_REGEXP
  CONFIRMATION_TOKEN_EXPIRES_IN = 24.hours
end
