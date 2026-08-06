class Core::User::Session::Revoke < ApplicationSolidProcess
  deps do
    attribute :session_repository, default: -> { User::Adapters.session_repository }

    validates :session_repository, kind_of: Core::User::Session::Repository::Interface
  end

  input do
    attribute :user

    validates :user, presence: true, kind_of: Core::User::Entity
  end

  def call(attributes)
    Given(attributes)
      .and_then(:revoke_user_sessions)
  end

  private

  def revoke_user_sessions(user:, **)
    case deps.session_repository.revoke_all_by(user_id: user.id)
    in Solid::Success then Continue()
    in Solid::Failure
      input.errors.add(:base, :sessions_revocation_failed)

      Failure(:sessions_revocation_failed, input:)
    end
  end
end
