class Core::Account::Listing < ApplicationSolidProcess
  DEFAULT_SORTING = "active desc, name asc"

  deps do
    attribute :account_repository, default: -> { Account::Adapters.repository }

    validates :account_repository, kind_of: Core::Account::Repository::Interface
  end

  input do
    attribute :user
    attribute :filters, default: -> { {} }
    attribute :sorting, :string, default: DEFAULT_SORTING
    attribute :page, :integer, default: 1
    attribute :per_page, :integer, default: Core::Pagination::DEFAULT_PER_PAGE

    validates :user, presence: true, kind_of: Core::User::Entity
    validates :filters, kind_of: Hash
    validates :sorting, presence: true
    validates :page, numericality: { only_integer: true, greater_than_or_equal_to: 1 }
    validates :per_page, numericality: {
      only_integer: true,
      greater_than_or_equal_to: 1,
      less_than_or_equal_to: Core::Pagination::MAX_PER_PAGE
    }
  end

  def call(attributes)
    Given(attributes)
      .and_then(:list_accounts)
  end

  private

  def list_accounts(user:, filters:, sorting:, page:, per_page:, **)
    case deps.account_repository.list(user:, filters:, sorting:, page:, per_page:)
    in Solid::Success(accounts:, pagination:)
      Continue(accounts:, pagination:)
    in Solid::Failure(type: :invalid_filters)
      input.errors.add(:q, :invalid)

      Failure(:invalid_filters, input:)
    end
  end
end
