class Core::User::Authentication < ApplicationSolidProcess
  deps do
    attribute :user_repository, default: -> { User::Adapters.repository }
    attribute :session_repository, default: -> { User::Adapters.session_repository }
    attribute :token_adapter, default: -> { User::Adapters.token }

    validates :user_repository, kind_of: Core::User::Repository::Interface
    validates :session_repository, kind_of: Core::User::Session::Repository::Interface
    validates :token_adapter, kind_of: Core::User::Token::Interface
  end

  input do
    attribute :email, :string
    attribute :password, :string
    attribute :remember_me, :boolean, default: false
    attribute :ip_address, :string
    attribute :user_agent, :string

    normalizes :email, with: ->(value) { value.strip.downcase }

    validates :email, :password, presence: true
  end

  def call(attributes)
    rollback_on_failure {
      Given(attributes)
        .and_then(:authenticate_user)
        .and_then(:check_if_user_email_is_verified)
        .and_then(:check_if_user_is_active)
        .and_then(:revoke_previous_sessions)
        .and_then(:create_refresh_token)
        .and_then(:create_session)
        .and_then(:create_signed_token)
    }
      .and_expose(:authenticated, %i[token refresh_token user remember_me])
  end

  private

  def authenticate_user(email:, password:, **)
    case deps.user_repository.find_by_email_and_password(email:, password:)
    in Solid::Success(user:) then Continue(user:)
    in Solid::Failure
      input.errors.add(:base, :invalid_email_or_password)

      Failure(:invalid_email_or_password, input:)
    end
  end

  def check_if_user_email_is_verified(user:, **)
    return Continue() if deps.user_repository.verified?(user:)

    input.errors.add(:base, :user_email_is_not_verified)

    Failure(:user_email_is_not_verified, input:)
  end

  def check_if_user_is_active(user:, **)
    return Continue() if deps.user_repository.active?(user:)

    input.errors.add(:base, :user_is_not_active)

    Failure(:user_is_not_active, input:)
  end

  def revoke_previous_sessions(user:, **)
    case deps.session_repository.revoke_all_by(user_id: user.id)
    in Solid::Success then Continue()
    in Solid::Failure
      input.errors.add(:base, :sessions_revocation_failed)

      Failure(:sessions_revocation_failed, input:)
    end
  end

  def create_refresh_token(**)
    refresh_token = deps.token_adapter.generate

    return Continue(refresh_token:) if refresh_token.present?

    input.errors.add(:base, :refresh_token_creation_failed)

    Failure(:refresh_token_creation_failed, input:)
  end

  def create_session(user:, user_agent:, ip_address:, refresh_token:, remember_me:, **)
    case deps.session_repository.create(user:, user_agent:, ip_address:, refresh_token:, remember_me:)
    in Solid::Success(session:) then Continue(session:)
    in Solid::Failure(errors:)
      add_errors_to_input(errors)

      Failure(:session_creation_failed, input:)
    end
  end

  def create_signed_token(user:, **)
    token = deps.token_adapter.sign(
      user:,
      purpose: :session_token,
      expires_in: Core::User::Token::SESSION_TOKEN_EXPIRES_IN
    )

    return Continue(token:) if token.present?

    input.errors.add(:base, :signed_token_creation_failed)

    Failure(:signed_token_creation_failed, input:)
  end
end
