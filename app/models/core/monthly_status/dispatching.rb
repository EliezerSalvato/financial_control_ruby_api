class Core::MonthlyStatus::Dispatching < ApplicationSolidProcess
  deps do
    attribute :monthly_status_repository, default: -> { MonthlyStatus::Adapters.repository }
    attribute :closing_job, default: -> { MonthlyStatus::Adapters.closing_job }

    validates :monthly_status_repository, kind_of: Core::MonthlyStatus::Repository::Interface
    validates :closing_job, kind_of: Core::MonthlyStatus::Closing::Job::Interface
  end

  input do
    attribute :date, :date

    validates :date, presence: true
  end

  def call(attributes)
    Given(attributes)
      .and_then(:list_users)
      .and_then(:enqueue)
      .and_expose(:monthly_dispatch_completed, %i[user_ids])
  end

  private

  def list_users(date:, **)
    previous = date.prev_month

    case deps.monthly_status_repository.user_ids_with_open_months(up_to_month: previous.month, up_to_year: previous.year)
    in Solid::Success(user_ids:) then Continue(user_ids:)
    end
  end

  def enqueue(user_ids:, date:, **)
    user_ids.each { |user_id| deps.closing_job.start(user_id:, date:) }

    Continue()
  end
end
