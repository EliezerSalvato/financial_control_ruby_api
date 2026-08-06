class Core::User::Registration < ApplicationSolidProcess
  deps do
    attribute :mailer, default: -> { User::Adapters.mailer }
    attribute :user_repository, default: -> { User::Adapters.repository }
    attribute :email_confirmation_repository, default: -> { User::Adapters.email_confirmation_repository }

    validates :mailer, kind_of: Core::User::Mailer::Interface
    validates :user_repository, kind_of: Core::User::Repository::Interface
    validates :email_confirmation_repository, kind_of: Core::User::Email::Confirmation::Repository::Interface
  end

  input do
    attribute :first_name, :string
    attribute :last_name, :string
    attribute :email, :string
    attribute :password, :string
    attribute :password_confirmation, :string

    normalizes :email, with: ->(value) { value.strip.downcase }
    normalizes :first_name, :last_name, with: ->(value) { value.strip }

    with_options presence: true do
      validates :first_name, :last_name
      validates :email, format: { with: Core::User::Email::FORMAT }
      validates :password, length: { minimum: Core::User::Password::MIN_LENGTH }, confirmation: true
    end
  end

  def call(attributes)
    rollback_on_failure {
      Given(attributes)
        .and_then(:check_if_email_is_taken)
        .and_then(:create_user)
        .and_then(:create_email_confirmation)
    }
      .and_then(:send_email_confirmation)
      .and_expose(:user_registered, %i[user])
  end

  private

  def check_if_email_is_taken(email:, **)
    input.errors.add(:email, :taken) if deps.user_repository.exists?(email:)

    return Failure(:invalid_input, input:) if input.errors.any?

    Continue()
  end

  def create_user(first_name:, last_name:, email:, password:, password_confirmation:, **)
    case deps.user_repository.create(first_name:, last_name:, email:, password:, password_confirmation:)
    in Solid::Success(user:) then Continue(user:)
    in Solid::Failure(errors:)
      add_errors_to_input(errors)

      Failure(:user_creation_failed, input:)
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
