class Core::User::Password::Change < ApplicationSolidProcess
  deps do
    attribute :user_repository, default: -> { User::Adapters.repository }
    attribute :session_repository, default: -> { User::Adapters.session_repository }

    validates :user_repository, kind_of: Core::User::Repository::Interface
    validates :session_repository, kind_of: Core::User::Session::Repository::Interface
  end

  input do
    attribute :user
    attribute :current_password, :string
    attribute :password, :string
    attribute :password_confirmation, :string

    with_options presence: true do
      validates :current_password
      validates :user, kind_of: Core::User::Entity
      validates :password, length: { minimum: Core::User::Password::MIN_LENGTH }, confirmation: true
    end
  end

  def call(attributes)
    rollback_on_failure {
      Given(attributes)
        .and_then(:authenticate_current_password)
        .and_then(:check_if_current_password_is_different_from_new_password)
        .and_then(:update_password)
        .and_then(:revoke_sessions)
    }
  end

  private

  def authenticate_current_password(user:, current_password:, **)
    case deps.user_repository.authenticate(user:, password: current_password)
    in Solid::Success then Continue()
    in Solid::Failure
      input.errors.add(:current_password, :invalid)

      Failure(:current_password_is_invalid, input:)
    end
  end

  def check_if_current_password_is_different_from_new_password(user:, current_password:, password:, **)
    return Continue() if current_password != password

    input.errors.add(:password, :same_as_current_password)

    Failure(:current_password_is_the_same_as_new_password, input:)
  end

  def update_password(user:, password:, password_confirmation:, **)
    case deps.user_repository.update_password(user:, password:, password_confirmation:)
    in Solid::Success(user:) then Continue(user:)
    in Solid::Failure(errors:)
      add_errors_to_input(errors)

      Failure(:password_update_failed, input:)
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
