class Core::Transaction::Finding < ApplicationSolidProcess
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
  end

  private

  def find_transaction(user:, id:, **)
    case deps.transaction_repository.find_by_id(user:, id:)
    in Solid::Success(transaction:) then Continue(transaction:)
    in Solid::Failure(type: :transaction_not_found) then Failure(:transaction_not_found)
    end
  end
end
