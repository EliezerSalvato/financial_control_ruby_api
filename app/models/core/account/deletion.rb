class Core::Account::Deletion < ApplicationSolidProcess
  deps do
    attribute :account_repository, default: -> { Account::Adapters.repository }

    validates :account_repository, kind_of: Core::Account::Repository::Interface
  end

  input do
    attribute :user
    attribute :id, :string

    validates :user, :id, presence: true
    validates :user, kind_of: Core::User::Entity
  end

  def call(attributes)
    Given(attributes)
      .and_then(:find_account)
      .and_then(:destroy_account)
  end

  private

  def find_account(user:, id:, **)
    case deps.account_repository.find_by_id(user:, id:)
    in Solid::Success(account:) then Continue(account:)
    in Solid::Failure(type: :account_not_found)
      Failure(:account_not_found)
    end
  end

  def destroy_account(account:, **)
    case deps.account_repository.destroy(account:)
    in Solid::Success then Continue()
    in Solid::Failure
      input.errors.add(:base, :account_destruction_failed)

      Failure(:account_destruction_failed, input:)
    end
  end
end
