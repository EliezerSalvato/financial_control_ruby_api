class Core::Transaction::ForAccount::Update < ApplicationSolidProcess
  deps do
    attribute :account_repository, default: -> { Account::Adapters.repository }
    attribute :transaction_for_account_repository, default: -> { Transaction::Adapters.transaction_for_account_repository }

    validates :account_repository, kind_of: Core::Account::Repository::Interface
    validates :transaction_for_account_repository, kind_of: Core::Transaction::ForAccount::Repository::Interface
  end

  input do
    attribute :user
    attribute :transaction
    attribute :kind, :string
    attribute :payment_method, :string
    attribute :account_id, :string

    validates :user, :transaction, presence: true
    validates :user, kind_of: Core::User::Entity
    validates :transaction, kind_of: Core::Transaction::Entity
  end

  def call(attributes)
    return Continue() if input.transaction.completed_or_canceled?

    if input.kind == Core::Transaction::Kind::TRANSFER_BETWEEN_ACCOUNTS || input.payment_method == Core::Transaction::PaymentMethod::CREDIT_CARD
      destroy_transaction_for_account(transaction: input.transaction)
    else
      Given(attributes)
        .and_then(:resolve_account_id)
        .and_then(:validate_presence)
        .and_then(:ensure_account_belongs_to_user)
        .and_then(:upsert_transaction_for_account)
    end
  end

  private

  def resolve_account_id(transaction:, account_id:, **)
    Continue(account_id: account_id.nil? ? transaction.account_id : account_id)
  end

  def validate_presence(account_id:, **)
    input.errors.add(:account_id, :blank) if account_id.blank?

    return Failure(:invalid_input, input:) if input.errors.any?

    Continue()
  end

  def ensure_account_belongs_to_user(user:, transaction:, account_id:, **)
    case deps.account_repository.find_by_id(user:, id: account_id)
    in Solid::Success(account:)
      return Continue() if account.active? || UUID.same?(account_id, transaction.account_id)

      input.errors.add(:account_id, :inactive)
      Failure(:invalid_input, input:)
    in Solid::Failure(type: :account_not_found)
      input.errors.add(:account_id, :not_found)
      Failure(:invalid_input, input:)
    end
  end

  def upsert_transaction_for_account(transaction:, account_id:, **)
    case deps.transaction_for_account_repository.upsert(transaction:, account_id:)
    in Solid::Success then Continue()
    in Solid::Failure(errors:)
      add_errors_to_input(errors)
      Failure(:for_account_upsert_failed, errors:)
    end
  end

  def destroy_transaction_for_account(transaction:)
    case deps.transaction_for_account_repository.destroy(transaction:)
    in Solid::Success then Continue()
    in Solid::Failure(errors:)
      add_errors_to_input(errors)
      Failure(:for_account_destruction_failed, errors:)
    end
  end
end
