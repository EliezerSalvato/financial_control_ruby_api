class Core::User::Password::Reset::SendInstructions < ApplicationSolidProcess
  deps do
    attribute :mailer, default: -> { User::Adapters.mailer }
    attribute :user_repository, default: -> { User::Adapters.repository }
    attribute :password_reset_repository, default: -> { User::Adapters.password_reset_repository }

    validates :mailer, kind_of: Core::User::Mailer::Interface
    validates :user_repository, kind_of: Core::User::Repository::Interface
    validates :password_reset_repository, kind_of: Core::User::Password::Reset::Repository::Interface
  end

  input do
    attribute :email, :string

    normalizes :email, with: ->(value) { value.strip.downcase }

    validates :email, presence: true, format: { with: Core::User::Email::FORMAT }
  end

  def call(attributes)
    rollback_on_failure {
      Given(attributes)
        .and_then(:find_user_by_email)
        .and_then(:check_if_user_is_active)
        .and_then(:check_if_user_email_is_verified)
        .and_then(:invalidate_previous_password_resets)
        .and_then(:create_password_reset)
    }
      .and_then(:send_password_reset_email)
  end

  private

  def find_user_by_email(email:, **)
    case deps.user_repository.find_by_email(email:)
    in Solid::Success(user:) then Continue(user:)
    in Solid::Failure
      input.errors.add(:email, :not_found)

      Failure(:email_not_found, input:)
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

  def invalidate_previous_password_resets(user:, **)
    case deps.password_reset_repository.invalidate_all_by(user_id: user.id)
    in Solid::Success then Continue()
    in Solid::Failure
      input.errors.add(:base, :password_resets_invalidation_failed)

      Failure(:password_resets_invalidation_failed, input:)
    end
  end

  def create_password_reset(user:, **)
    case deps.password_reset_repository.create(user:)
    in Solid::Success(password_reset:, token:) then Continue(token:)
    in Solid::Failure(errors:)
      add_errors_to_input(errors)

      Failure(:password_reset_creation_failed, input:)
    end
  end

  def send_password_reset_email(email:, token:, **)
    deps.mailer.deliver_password_reset(email:, token:)

    Continue()
  end
end
