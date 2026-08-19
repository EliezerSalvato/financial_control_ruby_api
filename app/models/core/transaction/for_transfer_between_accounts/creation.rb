class Core::Transaction::ForTransferBetweenAccounts::Creation < ApplicationSolidProcess
  deps do
    attribute :account_repository, default: -> { Account::Adapters.repository }
    attribute :transaction_for_transfer_between_accounts_repository, default: -> { Transaction::Adapters.transaction_for_transfer_between_accounts_repository }

    validates :account_repository, kind_of: Core::Account::Repository::Interface
    validates :transaction_for_transfer_between_accounts_repository, kind_of: Core::Transaction::ForTransferBetweenAccounts::Repository::Interface
  end

  input do
    attribute :user
    attribute :transaction
    attribute :source_account_id, :string
    attribute :destination_account_id, :string

    validates :user, :transaction, :source_account_id, :destination_account_id, presence: true
    validates :user, kind_of: Core::User::Entity
    validates :transaction, kind_of: Core::Transaction::Entity
  end

  def call(attributes)
    Given(attributes)
      .and_then(:validate_accounts_distinct)
      .and_then(:ensure_accounts_belong_to_user)
      .and_then(:create_transaction_for_transfer_between_accounts)
  end

  private

  def validate_accounts_distinct(source_account_id:, destination_account_id:, **)
    if source_account_id == destination_account_id
      input.errors.add(:destination_account_id, :same_as_source)

      return Failure(:invalid_input, input:)
    end

    Continue()
  end

  def ensure_accounts_belong_to_user(user:, source_account_id:, destination_account_id:, **)
    ensure_account!(user:, id: source_account_id, attribute: :source_account_id)
    ensure_account!(user:, id: destination_account_id, attribute: :destination_account_id) if input.errors.empty?

    return Failure(:invalid_input, input:) if input.errors.any?

    Continue()
  end

  def ensure_account!(user:, id:, attribute:)
    case deps.account_repository.find_by_id(user:, id:)
    in Solid::Success(account:)
      input.errors.add(attribute, :inactive) unless account.active?
    in Solid::Failure(type: :account_not_found)
      input.errors.add(attribute, :not_found)
    end
  end

  def create_transaction_for_transfer_between_accounts(transaction:, source_account_id:, destination_account_id:, **)
    case deps.transaction_for_transfer_between_accounts_repository.create(transaction:, source_account_id:, destination_account_id:)
    in Solid::Success then Continue()
    in Solid::Failure(errors:)
      add_errors_to_input(errors)
      Failure(:for_transfer_between_accounts_creation_failed, errors:)
    end
  end
end
