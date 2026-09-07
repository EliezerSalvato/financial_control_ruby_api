class Core::MonthlyStatus::OpenMonths::Closing < ApplicationSolidProcess
  NEXT_ATTEMPT_HOUR = 5

  rescue_from StandardError, with: :notify_unexpected_and_reraise

  deps do
    attribute :monthly_status_repository, default: -> { MonthlyStatus::Adapters.repository }
    attribute :closing_job, default: -> { MonthlyStatus::Adapters.closing_job }

    validates :monthly_status_repository, kind_of: Core::MonthlyStatus::Repository::Interface
    validates :closing_job, kind_of: Core::MonthlyStatus::Closing::Job::Interface
  end

  input do
    attribute :user_id, :string
    attribute :date, :date, default: -> { Date.current }

    validates :user_id, presence: true
    validates :date, presence: true
  end

  def call(attributes)
    Given(attributes)
      .and_then(:ensure_previous_month)
      .and_then(:list_open_months)
      .and_then(:close_open_months)
      .and_then(:notify_still_open)
      .and_then(:reschedule_if_needed)
      .and_expose(:monthly_closing_completed, %i[still_open])
  end

  private

  def ensure_previous_month(user_id:, date:, **)
    previous = date.prev_month
    up_to_month = previous.month
    up_to_year = previous.year

    case deps.monthly_status_repository.find(user_id:, month: up_to_month, year: up_to_year)
    in Solid::Success then Continue(up_to_month:, up_to_year:)
    in Solid::Failure(type: :monthly_status_not_found)
      create_previous_month(user_id:, up_to_month:, up_to_year:)
    end
  end

  def create_previous_month(user_id:, up_to_month:, up_to_year:)
    return Continue(up_to_month:, up_to_year:) if deps.monthly_status_repository.exists_closed_after?(
      user_id:,
      month: up_to_month,
      year: up_to_year
    )

    case deps.monthly_status_repository.create(user_id:, month: up_to_month, year: up_to_year)
    in Solid::Success then Continue(up_to_month:, up_to_year:)
    in Solid::Failure(errors:)
      add_errors_to_input(errors)
      Failure(:monthly_status_creation_failed, input:)
    end
  end

  def list_open_months(user_id:, up_to_month:, up_to_year:, **)
    case deps.monthly_status_repository.list_open_for(user_id:, up_to_month:, up_to_year:)
    in Solid::Success(monthly_statuses:) then Continue(monthly_statuses:)
    end
  end

  def close_open_months(user_id:, monthly_statuses:, **)
    still_open = monthly_statuses.filter_map { |monthly_status| pending_for(user_id:, monthly_status:) }

    Continue(still_open:)
  end

  def notify_still_open(user_id:, still_open:, **)
    return Continue() if still_open.empty?

    case Core::MonthlyStatus::Closing::ValidationErrorNotifying.call(user_id:, pending: still_open)
    in Solid::Success then Continue()
    else raise StandardError, "notifications_creation_failed"
    end
  end

  def reschedule_if_needed(user_id:, date:, still_open:, **)
    return Continue() if still_open.empty?

    today = Date.current
    tomorrow = today.tomorrow

    return Continue() if tomorrow.month != today.month

    deps.closing_job.schedule(user_id:, date:, wait_until: tomorrow.in_time_zone.change(hour: NEXT_ATTEMPT_HOUR))

    Continue()
  end

  def pending_for(user_id:, monthly_status:)
    case Core::MonthlyStatus::Closing.call(user_id:, month: monthly_status.month, year: monthly_status.year)
    in Solid::Success(type: :monthly_status_closed) then nil
    in Solid::Success(pending_occurrences:, pending_invoices:)
      { month: monthly_status.month, year: monthly_status.year, monthly_status_id: monthly_status.id, pending_occurrences:, pending_invoices: }
    in Solid::Failure(type:)
      { month: monthly_status.month, year: monthly_status.year, monthly_status_id: monthly_status.id, failure: type }
    end
  end

  def notify_unexpected_and_reraise(exception)
    notify_unexpected_error(exception)
    raise exception
  end

  def notify_unexpected_error(exception)
    return if input.user_id.blank?

    Core::MonthlyStatus::Closing::UnexpectedErrorNotifying.call(
      user_id: input.user_id,
      type: :unexpected,
      error: exception.class.name
    )
  rescue StandardError
    nil
  end
end
