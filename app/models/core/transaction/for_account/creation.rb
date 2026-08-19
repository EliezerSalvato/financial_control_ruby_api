class Core::Transaction::ForAccount::Creation < ApplicationSolidProcess
  deps do
    attribute :account_repository, default: -> { Account::Adapters.repository }
    attribute :transaction_for_account_repository, default: -> { Transaction::Adapters.transaction_for_account_repository }

    validates :account_repository, kind_of: Core::Account::Repository::Interface
    validates :transaction_for_account_repository, kind_of: Core::Transaction::ForAccount::Repository::Interface
  end

  input do
    attribute :user
    attribute :transaction
    attribute :account_id, :string

    validates :user, :transaction, :account_id, presence: true
    validates :user, kind_of: Core::User::Entity
    validates :transaction, kind_of: Core::Transaction::Entity
  end

  def call(attributes)
    Given(attributes)
      .and_then(:ensure_account_belongs_to_user)
      .and_then(:create_transaction_for_account)
  end

  private

  def ensure_account_belongs_to_user(user:, account_id:, **)
    case deps.account_repository.find_by_id(user:, id: account_id)
    in Solid::Success(account:)
      return Continue() if account.active?

      input.errors.add(:account_id, :inactive)
      Failure(:invalid_input, input:)
    in Solid::Failure(type: :account_not_found)
      input.errors.add(:account_id, :not_found)
      Failure(:invalid_input, input:)
    end
  end

  def create_transaction_for_account(transaction:, account_id:, **)
    case deps.transaction_for_account_repository.create(transaction:, account_id:)
    in Solid::Success then Continue()
    in Solid::Failure(errors:)
      add_errors_to_input(errors)
      Failure(:for_account_creation_failed, errors:)
    end
  end
end
