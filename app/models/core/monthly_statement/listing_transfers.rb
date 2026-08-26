class Core::MonthlyStatement::ListingTransfers < ApplicationSolidProcess
  deps do
    attribute :monthly_statement_repository, default: -> { MonthlyStatement::Adapters.repository }

    validates :monthly_statement_repository, kind_of: Core::MonthlyStatement::Repository::Interface
  end

  input do
    attribute :user
    attribute :month, :integer
    attribute :year, :integer

    validates :user, presence: true, kind_of: Core::User::Entity
    validates :month, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 12 }
    validates :year, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 9999 }
  end

  def call(attributes)
    Given(attributes)
      .and_then(:list_monthly_statement_transfers)
  end

  private

  def list_monthly_statement_transfers(user:, month:, year:, **)
    case deps.monthly_statement_repository.list_transfers(user_id: user.id, month:, year:)
    in Solid::Success(monthly_statement_transfers:)
      Continue(monthly_statement_transfers:)
    end
  end
end
