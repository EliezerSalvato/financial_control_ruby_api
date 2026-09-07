class Core::MonthlyStatus::Update < ApplicationSolidProcess
  deps do
    attribute :monthly_status_repository, default: -> { MonthlyStatus::Adapters.repository }

    validates :monthly_status_repository, kind_of: Core::MonthlyStatus::Repository::Interface
  end

  input do
    attribute :user
    attribute :month, :integer
    attribute :year, :integer
    attribute :status, :string

    validates :user, presence: true, kind_of: Core::User::Entity
    validates :month, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 12 }
    validates :year, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 9999 }
    validates :status, presence: true, inclusion: { in: Core::MonthlyStatus::Status::ALL }
  end

  def call(attributes)
    Given(attributes)
      .and_then(:find_or_create_monthly_status)
      .and_then(:update_monthly_status)
  end

  private

  def find_or_create_monthly_status(user:, month:, year:, **)
    case deps.monthly_status_repository.find(user_id: user.id, month:, year:)
    in Solid::Success(monthly_status:) then Continue(monthly_status:)
    in Solid::Failure(type: :monthly_status_not_found)
      create_monthly_status(user_id: user.id, month:, year:)
    end
  end

  def create_monthly_status(user_id:, month:, year:)
    if deps.monthly_status_repository.exists_closed_after?(user_id:, month:, year:)
      input.errors.add(:base, :later_month_closed)
      return Failure(:later_month_closed, input:)
    end

    case deps.monthly_status_repository.create(user_id:, month:, year:)
    in Solid::Success(monthly_status:) then Continue(monthly_status:)
    in Solid::Failure(errors:)
      add_errors_to_input(errors)
      Failure(:monthly_status_creation_failed, input:)
    end
  end

  def update_monthly_status(monthly_status:, status:, **)
    case deps.monthly_status_repository.update(monthly_status:, attributes: { status: })
    in Solid::Success(monthly_status:) then Continue(monthly_status:)
    in Solid::Failure(errors:)
      add_errors_to_input(errors)
      input.errors.add(:base, :monthly_status_update_failed)
      Failure(:monthly_status_update_failed, input:)
    end
  end
end
