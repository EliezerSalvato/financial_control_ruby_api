class Core::MonthlyStatement::Listing < ApplicationSolidProcess
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
      .and_then(:list_monthly_statements)
  end

  private

  def list_monthly_statements(user:, month:, year:, **)
    case deps.monthly_statement_repository.list(user:, month:, year:)
    in Solid::Success(monthly_statements:)
      Continue(monthly_statements:)
    end
  end
end
