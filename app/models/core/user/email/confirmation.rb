class Core::User::Email::Confirmation < ApplicationSolidProcess
  deps do
    attribute :user_repository, default: -> { User::Adapters.repository }
    attribute :email_confirmation_repository, default: -> { User::Adapters.email_confirmation_repository }

    validates :user_repository, kind_of: Core::User::Repository::Interface
    validates :email_confirmation_repository, kind_of: Core::User::Email::Confirmation::Repository::Interface
  end

  input do
    attribute :token, :string

    validates :token, presence: true
  end

  def call(attributes)
    rollback_on_failure {
      Given(attributes)
        .and_then(:find_user_by_confirmation_token)
        .and_then(:find_email_confirmation)
        .and_then(:mark_user_as_verified)
        .and_then(:mark_email_confirmation_as_confirmed)
    }
  end

  private

  def find_user_by_confirmation_token(token:, **)
    case deps.user_repository.find_by_confirmation_token(token:)
    in Solid::Success(user:) then Continue(user:)
    in Solid::Failure
      input.errors.add(:base, :invalid_token)

      Failure(:invalid_token, input:)
    end
  end

  def find_email_confirmation(token:, **)
    case deps.email_confirmation_repository.find_by_token(token:)
    in Solid::Success(email_confirmation:) then Continue(email_confirmation:)
    in Solid::Failure
      input.errors.add(:base, :invalid_token)

      Failure(:invalid_token, input:)
    end
  end

  def mark_user_as_verified(user:, **)
    case deps.user_repository.mark_as_verified(user:)
    in Solid::Success(user:) then Continue(user:)
    in Solid::Failure
      input.errors.add(:base, :mark_user_as_verified_failed)

      Failure(:mark_user_as_verified_failed, input:)
    end
  end

  def mark_email_confirmation_as_confirmed(email_confirmation:, **)
    case deps.email_confirmation_repository.mark_as_confirmed(email_confirmation:)
    in Solid::Success(email_confirmation:) then Continue(email_confirmation:)
    in Solid::Failure
      input.errors.add(:base, :mark_email_confirmation_as_confirmed_failed)

      Failure(:mark_email_confirmation_as_confirmed_failed, input:)
    end
  end
end
