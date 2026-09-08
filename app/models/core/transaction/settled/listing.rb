class Core::Transaction::Settled::Listing < ApplicationSolidProcess
  deps do
    attribute :settlement_repository, default: -> { Transaction::Adapters.settlement_repository }

    validates :settlement_repository, kind_of: Core::Transaction::Settlement::Repository::Interface
  end

  input do
    attribute :user
    attribute :month, :integer
    attribute :year, :integer
    attribute :type, :string

    validates :user, presence: true, kind_of: Core::User::Entity
    validates :month, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 12 }
    validates :year, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 9999 }
    validates :type, inclusion: { in: Core::Transaction::Settled::Type::ALL }, allow_blank: true
  end

  def call(attributes)
    Given(attributes)
      .and_then(:list_settled_transactions)
  end

  private

  def list_settled_transactions(user:, month:, year:, type: nil, **)
    case deps.settlement_repository.list_for_month(user:, month:, year:, type: type.presence)
    in Solid::Success(settled_transactions:)
      Continue(settled_transactions:)
    end
  end
end
