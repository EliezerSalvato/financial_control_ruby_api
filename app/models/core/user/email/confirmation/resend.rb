class Core::User::Email::Confirmation::Resend < ApplicationSolidProcess
  deps do
    attribute :mailer, default: -> { User::Adapters.mailer }
    attribute :user_repository, default: -> { User::Adapters.repository }
    attribute :email_confirmation_repository, default: -> { User::Adapters.email_confirmation_repository }

    validates :mailer, kind_of: Core::User::Mailer::Interface
    validates :user_repository, kind_of: Core::User::Repository::Interface
    validates :email_confirmation_repository, kind_of: Core::User::Email::Confirmation::Repository::Interface
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
        .and_then(:check_if_user_email_is_unverified)
        .and_then(:invalidate_previous_email_confirmations)
        .and_then(:create_email_confirmation)
    }
      .and_then(:send_email_confirmation)
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

  def check_if_user_email_is_unverified(user:, **)
    return Continue() unless deps.user_repository.verified?(user:)

    input.errors.add(:base, :user_email_is_already_verified)

    Failure(:user_email_is_already_verified, input:)
  end

  def invalidate_previous_email_confirmations(user:, **)
    case deps.email_confirmation_repository.invalidate_all_by(user_id: user.id)
    in Solid::Success then Continue()
    in Solid::Failure
      input.errors.add(:base, :email_confirmations_invalidation_failed)

      Failure(:email_confirmations_invalidation_failed, input:)
    end
  end

  def create_email_confirmation(user:, **)
    case deps.email_confirmation_repository.create(user:)
    in Solid::Success(email_confirmation:, token:) then Continue(token:)
    in Solid::Failure(errors:)
      add_errors_to_input(errors)

      Failure(:email_confirmation_creation_failed, input:)
    end
  end

  def send_email_confirmation(email:, token:, **)
    deps.mailer.deliver_confirmation(email:, token:)

    Continue()
  end
end
