class Core::Transaction::Deletion < ApplicationSolidProcess
  deps do
    attribute :transaction_repository, default: -> { Transaction::Adapters.repository }

    validates :transaction_repository, kind_of: Core::Transaction::Repository::Interface
  end

  input do
    attribute :user
    attribute :id, :string

    validates :user, :id, presence: true
    validates :user, kind_of: Core::User::Entity
  end

  def call(attributes)
    Given(attributes)
      .and_then(:find_transaction)
      .and_then(:reject_invalid_status)
      .and_then(:destroy_transaction)
  end

  private

  def find_transaction(user:, id:, **)
    case deps.transaction_repository.find_by_id(user:, id:)
    in Solid::Success(transaction:) then Continue(transaction:)
    in Solid::Failure(type: :transaction_not_found)
      Failure(:transaction_not_found)
    end
  end

  def reject_invalid_status(transaction:, **)
    return Continue() if transaction.pending?

    input.errors.add(:base, :cannot_be_destroyed)
    Failure(:transaction_cannot_be_destroyed, input:)
  end

  def destroy_transaction(transaction:, **)
    case deps.transaction_repository.destroy(transaction:)
    in Solid::Success then Continue()
    in Solid::Failure
      input.errors.add(:base, :transaction_destruction_failed)
      Failure(:transaction_destruction_failed, input:)
    end
  end
end
