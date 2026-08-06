module Core::User::Token
  SESSION_TOKEN_EXPIRES_IN = 15.minutes
  REFRESH_TOKEN_EXPIRES_IN = 30.days
  SHORT_REFRESH_TOKEN_EXPIRES_IN = 1.day

  def self.refresh_token_expires_in(remember_me:)
    remember_me ? REFRESH_TOKEN_EXPIRES_IN : SHORT_REFRESH_TOKEN_EXPIRES_IN
  end
end
