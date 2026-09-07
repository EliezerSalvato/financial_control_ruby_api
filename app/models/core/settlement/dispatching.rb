class Core::Settlement::Dispatching < ApplicationSolidProcess
  deps do
    attribute :monthly_status_repository, default: -> { MonthlyStatus::Adapters.repository }
    attribute :processing_job, default: -> { Settlement::Adapters.processing_job }

    validates :monthly_status_repository, kind_of: Core::MonthlyStatus::Repository::Interface
    validates :processing_job, kind_of: Core::Settlement::Processing::Job::Interface
  end

  input do
    attribute :date, :date

    validates :date, presence: true
  end

  def call(attributes)
    Given(attributes)
      .and_then(:list_open_months)
      .and_then(:start_eligible)
      .and_expose(:daily_dispatch_completed, %i[enqueued])
  end

  private

  def list_open_months(date:, **)
    case deps.monthly_status_repository.list_open(up_to_month: date.month, up_to_year: date.year)
    in Solid::Success(monthly_statuses:) then Continue(monthly_statuses:)
    end
  end

  def start_eligible(date:, monthly_statuses:, **)
    open_keys = monthly_statuses.map { |monthly_status| [ monthly_status.user_id, monthly_status.year, monthly_status.month ] }.to_set

    enqueued = monthly_statuses.filter_map do |monthly_status|
      next if previous_month_open?(monthly_status, open_keys)
      next if later_month_closed?(monthly_status)

      reference_date = Core::Settlement::ReferenceDate.for(monthly_status:, today: date) or next

      deps.processing_job.start(
        user_id: monthly_status.user_id,
        month: monthly_status.month,
        year: monthly_status.year,
        reference_date:
      )

      { user_id: monthly_status.user_id, month: monthly_status.month, year: monthly_status.year, reference_date: }
    end

    Continue(enqueued:)
  end

  def previous_month_open?(monthly_status, open_keys)
    previous = Date.new(monthly_status.year, monthly_status.month, 1).prev_month

    open_keys.include?([ monthly_status.user_id, previous.year, previous.month ])
  end

  def later_month_closed?(monthly_status)
    deps.monthly_status_repository.exists_closed_after?(
      user_id: monthly_status.user_id,
      month: monthly_status.month,
      year: monthly_status.year
    )
  end
end
