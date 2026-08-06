module User::Token::Adapters::ActiveRecord
  include Core::User::Token::Interface
  extend self

  def generate
    SecureRandom.urlsafe_base64(64)
  end

  def digest(token)
    Digest::SHA256.hexdigest(token)
  end

  def generate_for(user:, purpose:)
    User::Mapper.to_record(user).generate_token_for(purpose)
  end

  def find_by(purpose:, token:)
    User::Mapper.to_entity(User::Record.find_by_token_for(purpose, token))
  end

  def sign(user:, purpose:, expires_in:)
    User::Mapper.to_record(user).signed_id(purpose:, expires_in:)
  end
end
