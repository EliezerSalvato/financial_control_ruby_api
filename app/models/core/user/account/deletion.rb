class Core::User::Account::Deletion < ApplicationSolidProcess
  deps do
    attribute :user_repository, default: -> { User::Adapters.repository }

    validates :user_repository, kind_of: Core::User::Repository::Interface
  end

  input do
    attribute :user
    attribute :password, :string

    validates :user, :password, presence: true
    validates :user, kind_of: Core::User::Entity
  end

  def call(attributes)
    Given(attributes)
      .and_then(:authenticate_password)
      .and_then(:destroy_user)
  end

  private

  def authenticate_password(user:, password:, **)
    case deps.user_repository.authenticate(user:, password:)
    in Solid::Success then Continue()
    in Solid::Failure
      input.errors.add(:password, :invalid)

      Failure(:password_is_invalid, input:)
    end
  end

  def destroy_user(user:, **)
    case deps.user_repository.destroy(user:)
    in Solid::Success then Continue()
    in Solid::Failure
      input.errors.add(:base, :account_deletion_failed)

      Failure(:account_deletion_failed, input:)
    end
  end
end
