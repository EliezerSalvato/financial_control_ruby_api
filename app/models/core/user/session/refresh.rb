class Core::User::Session::Refresh < ApplicationSolidProcess
  deps do
    attribute :session_repository, default: -> { User::Adapters.session_repository }
    attribute :user_repository, default: -> { User::Adapters.repository }
    attribute :token_adapter, default: -> { User::Adapters.token }

    validates :session_repository, kind_of: Core::User::Session::Repository::Interface
    validates :user_repository, kind_of: Core::User::Repository::Interface
    validates :token_adapter, kind_of: Core::User::Token::Interface
  end

  input do
    attribute :refresh_token, :string
    attribute :remember_me, :boolean, default: false

    validates :refresh_token, presence: true
  end

  def call(attributes)
    rollback_on_failure {
      Given(attributes)
        .and_then(:find_session)
        .and_then(:check_if_user_is_active)
        .and_then(:create_refresh_token)
        .and_then(:update_session)
        .and_then(:create_signed_token)
    }
      .and_expose(:session_refreshed, %i[token refresh_token user remember_me])
  end

  private

  def find_session(refresh_token:, **)
    case deps.session_repository.find_by_refresh_token(refresh_token:)
    in Solid::Success(session:, user:) then Continue(session:, user:)
    in Solid::Failure
      input.errors.add(:base, :invalid_refresh_token)

      Failure(:invalid_refresh_token, input:)
    end
  end

  def check_if_user_is_active(user:, **)
    return Continue() if deps.user_repository.active?(user:)

    input.errors.add(:base, :user_is_not_active)

    Failure(:user_is_not_active, input:)
  end

  def create_refresh_token(**)
    refresh_token = deps.token_adapter.generate

    return Continue(refresh_token:) if refresh_token.present?

    input.errors.add(:base, :refresh_token_creation_failed)

    Failure(:refresh_token_creation_failed, input:)
  end

  def update_session(session:, refresh_token:, remember_me:, **)
    case deps.session_repository.update_refresh_token(session:, refresh_token:, remember_me:)
    in Solid::Success(session:) then Continue(session:)
    in Solid::Failure(errors:)
      add_errors_to_input(errors)

      Failure(:refresh_token_update_failed, input:)
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
