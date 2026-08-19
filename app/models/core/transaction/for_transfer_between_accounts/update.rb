class Core::Transaction::ForTransferBetweenAccounts::Update < ApplicationSolidProcess
  deps do
    attribute :account_repository, default: -> { Account::Adapters.repository }
    attribute :transaction_for_transfer_between_accounts_repository, default: -> { Transaction::Adapters.transaction_for_transfer_between_accounts_repository }

    validates :account_repository, kind_of: Core::Account::Repository::Interface
    validates :transaction_for_transfer_between_accounts_repository, kind_of: Core::Transaction::ForTransferBetweenAccounts::Repository::Interface
  end

  input do
    attribute :user
    attribute :transaction
    attribute :kind, :string
    attribute :source_account_id, :string
    attribute :destination_account_id, :string

    validates :user, :transaction, presence: true
    validates :user, kind_of: Core::User::Entity
    validates :transaction, kind_of: Core::Transaction::Entity
  end

  def call(attributes)
    return Continue() if input.transaction.completed_or_canceled?

    if input.kind == Core::Transaction::Kind::TRANSFER_BETWEEN_ACCOUNTS
      Given(attributes)
        .and_then(:resolve_account_ids)
        .and_then(:validate_presence)
        .and_then(:validate_accounts_distinct)
        .and_then(:ensure_accounts_belong_to_user)
        .and_then(:upsert_transaction_for_transfer_between_accounts)
    else
      destroy_transaction_for_transfer_between_accounts(transaction: input.transaction)
    end
  end

  private

  def resolve_account_ids(transaction:, source_account_id:, destination_account_id:, **)
    source_account_id = source_account_id.nil? ? transaction.source_account_id : source_account_id
    destination_account_id = destination_account_id.nil? ? transaction.destination_account_id : destination_account_id

    Continue(source_account_id:, destination_account_id:)
  end

  def validate_presence(source_account_id:, destination_account_id:, **)
    input.errors.add(:source_account_id, :blank) if source_account_id.blank?
    input.errors.add(:destination_account_id, :blank) if destination_account_id.blank?

    return Failure(:invalid_input, input:) if input.errors.any?

    Continue()
  end

  def validate_accounts_distinct(source_account_id:, destination_account_id:, **)
    if source_account_id == destination_account_id
      input.errors.add(:destination_account_id, :same_as_source)
      return Failure(:invalid_input, input:)
    end

    Continue()
  end

  def ensure_accounts_belong_to_user(user:, transaction:, source_account_id:, destination_account_id:, **)
    ensure_account!(user:, id: source_account_id, attribute: :source_account_id, current_id: transaction.source_account_id)
    ensure_account!(user:, id: destination_account_id, attribute: :destination_account_id, current_id: transaction.destination_account_id)

    return Failure(:invalid_input, input:) if input.errors.any?

    Continue()
  end

  def ensure_account!(user:, id:, attribute:, current_id:)
    return if id.blank?

    case deps.account_repository.find_by_id(user:, id:)
    in Solid::Success(account:)
      input.errors.add(attribute, :inactive) unless account.active? || UUID.same?(id, current_id)
    in Solid::Failure(type: :account_not_found)
      input.errors.add(attribute, :not_found)
    end
  end

  def upsert_transaction_for_transfer_between_accounts(transaction:, source_account_id:, destination_account_id:, **)
    case deps.transaction_for_transfer_between_accounts_repository.upsert(transaction:, source_account_id:, destination_account_id:)
    in Solid::Success then Continue()
    in Solid::Failure(errors:)
      add_errors_to_input(errors)
      Failure(:for_transfer_between_accounts_upsert_failed, errors:)
    end
  end

  def destroy_transaction_for_transfer_between_accounts(transaction:)
    case deps.transaction_for_transfer_between_accounts_repository.destroy(transaction:)
    in Solid::Success then Continue()
    in Solid::Failure(errors:)
      add_errors_to_input(errors)
      Failure(:for_transfer_between_accounts_destruction_failed, errors:)
    end
  end
end
