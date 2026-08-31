class MonthlyStatus::MonthlyClosingJob < ApplicationJob
  include RetryableWithLogging

  queue_as :default

  NEXT_ATTEMPT_HOUR = 5

  def perform(user_id:)
    today = Date.current
    previous = today.prev_month

    case MonthlyStatus::Adapters.repository.list_open_for(user_id:, up_to_month: previous.month, up_to_year: previous.year)
    in Solid::Success(monthly_statuses:)
      still_open = monthly_statuses.filter_map { |monthly_status| close(user_id:, monthly_status:) }

      return if still_open.empty?

      Rails.logger.warn("[monthly_status] months not closed user_id=#{user_id} pending=#{still_open.inspect}")

      schedule_next_attempt(user_id:, today:)
    end
  end

  private

  def close(user_id:, monthly_status:)
    case MonthlyStatus.close(user_id:, month: monthly_status.month, year: monthly_status.year)
    in Solid::Success(type: :monthly_status_closed) then nil
    in Solid::Success(pending_occurrences:, pending_invoices:)
      { month: monthly_status.month, year: monthly_status.year, pending_occurrences:, pending_invoices: }
    in Solid::Failure(type:)
      { month: monthly_status.month, year: monthly_status.year, failure: type }
    end
  end

  def schedule_next_attempt(user_id:, today:)
    tomorrow = today.tomorrow

    # If tomorrow is already another month, MonthlyDispatchJob on day 1 owns the next attempt.
    return if tomorrow.month != today.month

    self.class
      .set(wait_until: tomorrow.in_time_zone.change(hour: NEXT_ATTEMPT_HOUR))
      .perform_later(user_id:)
  end
end
