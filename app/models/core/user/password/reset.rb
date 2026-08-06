class Core::User::Password::Reset < ApplicationSolidProcess
  deps do
    attribute :user_repository, default: -> { User::Adapters.repository }
    attribute :password_reset_repository, default: -> { User::Adapters.password_reset_repository }
    attribute :session_repository, default: -> { User::Adapters.session_repository }

    validates :user_repository, kind_of: Core::User::Repository::Interface
    validates :password_reset_repository, kind_of: Core::User::Password::Reset::Repository::Interface
    validates :session_repository, kind_of: Core::User::Session::Repository::Interface
  end

  input do
    attribute :token, :string
    attribute :password, :string
    attribute :password_confirmation, :string

    with_options presence: true do
      validates :token
      validates :password, length: { minimum: Core::User::Password::MIN_LENGTH }, confirmation: true
    end
  end

  def call(attributes)
    rollback_on_failure {
      Given(attributes)
        .and_then(:find_user_by_reset_password_token)
        .and_then(:check_if_user_is_active)
        .and_then(:check_if_user_email_is_verified)
        .and_then(:find_password_reset)
        .and_then(:check_if_current_password_is_different_from_new_password)
        .and_then(:update_password)
        .and_then(:mark_password_reset_as_reset)
        .and_then(:revoke_sessions)
    }
  end

  private

  def find_user_by_reset_password_token(token:, **)
    case deps.user_repository.find_by_reset_password_token(token:)
    in Solid::Success(user:) then Continue(user:)
    in Solid::Failure
      input.errors.add(:base, :invalid_token)

      Failure(:invalid_token, input:)
    end
  end

  def check_if_user_is_active(user:, **)
    return Continue() if deps.user_repository.active?(user:)

    input.errors.add(:base, :user_is_not_active)

    Failure(:user_is_not_active, input:)
  end

  def check_if_user_email_is_verified(user:, **)
    return Continue() if deps.user_repository.verified?(user:)

    input.errors.add(:base, :user_email_is_not_verified)

    Failure(:user_email_is_not_verified, input:)
  end

  def find_password_reset(token:, **)
    case deps.password_reset_repository.find_by_token(token:)
    in Solid::Success(password_reset:) then Continue(password_reset:)
    in Solid::Failure
      input.errors.add(:base, :invalid_token)

      Failure(:invalid_token, input:)
    end
  end

  def check_if_current_password_is_different_from_new_password(user:, password:, **)
    case deps.user_repository.authenticate(user:, password:)
    in Solid::Success(user:)
      input.errors.add(:password, :same_as_current_password)

      Failure(:current_password_is_the_same_as_new_password, input:)
    in Solid::Failure then Continue()
    end
  end

  def update_password(user:, password:, password_confirmation:, **)
    case deps.user_repository.update_password(user:, password:, password_confirmation:)
    in Solid::Success(user:) then Continue(user:)
    in Solid::Failure(errors:)
      add_errors_to_input(errors)

      Failure(:password_update_failed, input:)
    end
  end

  def mark_password_reset_as_reset(password_reset:, **)
    case deps.password_reset_repository.mark_as_reset(password_reset:)
    in Solid::Success(password_reset:) then Continue(password_reset:)
    in Solid::Failure
      input.errors.add(:base, :mark_password_reset_as_reset_failed)

      Failure(:mark_password_reset_as_reset_failed, input:)
    end
  end

  def revoke_sessions(user:, **)
    case deps.session_repository.revoke_all_by(user_id: user.id)
    in Solid::Success then Continue()
    in Solid::Failure
      input.errors.add(:base, :sessions_revocation_failed)

      Failure(:sessions_revocation_failed, input:)
    end
  end
end
