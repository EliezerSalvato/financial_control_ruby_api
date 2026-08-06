class Core::User::Profile::Update < ApplicationSolidProcess
  deps do
    attribute :user_repository, default: -> { User::Adapters.repository }

    validates :user_repository, kind_of: Core::User::Repository::Interface
  end

  input do
    attribute :user
    attribute :first_name, :string
    attribute :last_name, :string

    normalizes :first_name, :last_name, with: ->(value) { value.strip }

    validates :user, :first_name, :last_name, presence: true
    validates :user, kind_of: Core::User::Entity
  end

  def call(attributes)
    Given(attributes)
      .and_then(:update_profile)
  end

  private

  def update_profile(user:, first_name:, last_name:, **)
    case deps.user_repository.update_profile(user:, first_name:, last_name:)
    in Solid::Success(user:) then Continue(user:)
    in Solid::Failure(errors:)
      add_errors_to_input(errors)

      Failure(:profile_update_failed, input:)
    end
  end
end
