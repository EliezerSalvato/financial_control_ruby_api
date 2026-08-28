class Core::MonthlyStatus::Finding < ApplicationSolidProcess
  deps do
    attribute :monthly_status_repository, default: -> { MonthlyStatus::Adapters.repository }

    validates :monthly_status_repository, kind_of: Core::MonthlyStatus::Repository::Interface
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
      .and_then(:find_monthly_status)
  end

  private

  def find_monthly_status(user:, month:, year:, **)
    case deps.monthly_status_repository.find(user_id: user.id, month:, year:)
    in Solid::Success(monthly_status:) then Continue(monthly_status:)
    in Solid::Failure(type: :monthly_status_not_found) then Failure(:monthly_status_not_found)
    end
  end
end
