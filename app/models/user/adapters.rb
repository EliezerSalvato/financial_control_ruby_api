module User::Adapters
  extend Solid::Adapters::Configurable

  config.mailer = User::Mailer::Adapters::ActionMailer.new
  config.repository = User::Repository::Adapters::ActiveRecord
  config.email_confirmation_repository = User::Email::Confirmation::Repository::Adapters::ActiveRecord
  config.password_reset_repository = User::Password::Reset::Repository::Adapters::ActiveRecord
  config.session_repository = User::Session::Repository::Adapters::ActiveRecord
  config.token = User::Token::Adapters::ActiveRecord

  def self.mailer = config.mailer
  def self.repository = config.repository
  def self.email_confirmation_repository = config.email_confirmation_repository
  def self.password_reset_repository = config.password_reset_repository
  def self.session_repository = config.session_repository
  def self.token = config.token
end
