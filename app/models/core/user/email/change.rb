class Core::User::Email::Change < ApplicationSolidProcess
  deps do
    attribute :mailer, default: -> { User::Adapters.mailer }
    attribute :user_repository, default: -> { User::Adapters.repository }
    attribute :session_repository, default: -> { User::Adapters.session_repository }
    attribute :email_confirmation_repository, default: -> { User::Adapters.email_confirmation_repository }

    validates :mailer, kind_of: Core::User::Mailer::Interface
    validates :user_repository, kind_of: Core::User::Repository::Interface
    validates :session_repository, kind_of: Core::User::Session::Repository::Interface
    validates :email_confirmation_repository, kind_of: Core::User::Email::Confirmation::Repository::Interface
  end

  input do
    attribute :user
    attribute :current_password, :string
    attribute :new_email, :string

    normalizes :new_email, with: ->(value) { value.strip.downcase }

    with_options presence: true do
      validates :current_password
      validates :user, kind_of: Core::User::Entity
      validates :new_email, format: { with: Core::User::Email::FORMAT }
    end
  end

  def call(attributes)
    rollback_on_failure {
      Given(attributes)
        .and_then(:authenticate_current_password)
        .and_then(:check_if_new_email_is_the_same_as_the_current_email)
        .and_then(:check_if_new_email_is_taken)
        .and_then(:change_email_and_mark_as_not_verified)
        .and_then(:invalidate_previous_email_confirmations)
        .and_then(:create_email_confirmation)
        .and_then(:revoke_sessions)
    }
      .and_then(:send_email_confirmation)
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

  def check_if_new_email_is_the_same_as_the_current_email(user:, new_email:, **)
    return Continue() if user.email != new_email

    input.errors.add(:base, :new_email_is_the_same_as_the_current_email)

    Failure(:new_email_is_the_same_as_the_current_email, input:)
  end

  def check_if_new_email_is_taken(user:, new_email:, **)
    input.errors.add(:new_email, :taken) if deps.user_repository.exists?(email: new_email)

    return Failure(:invalid_input, input:) if input.errors.any?

    Continue()
  end

  def change_email_and_mark_as_not_verified(user:, new_email:, **)
    old_email = user.email

    case deps.user_repository.change_email_and_mark_as_not_verified(user:, new_email:)
    in Solid::Success(user:) then Continue(user:, old_email:)
    in Solid::Failure
      input.errors.add(:base, :change_email_and_mark_as_not_verified_failed)

      Failure(:change_email_and_mark_as_not_verified_failed, input:)
    end
  end

  def invalidate_previous_email_confirmations(user:, **)
    case deps.email_confirmation_repository.invalidate_all_by(user_id: user.id)
    in Solid::Success then Continue()
    in Solid::Failure
      input.errors.add(:base, :email_confirmations_invalidation_failed)

      Failure(:email_confirmations_invalidation_failed, input:)
    end
  end

  def create_email_confirmation(user:, old_email:, **)
    case deps.email_confirmation_repository.create(user:, old_email:)
    in Solid::Success(email_confirmation:, token:) then Continue(token:)
    in Solid::Failure(errors:)
      add_errors_to_input(errors)

      Failure(:email_confirmation_creation_failed, input:)
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

  def send_email_confirmation(new_email:, token:, **)
    deps.mailer.deliver_confirmation(email: new_email, token:)

    Continue()
  end
end
