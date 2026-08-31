class MonthlyStatus::MonthlyDispatchJob < ApplicationJob
  include RetryableWithLogging

  queue_as :default

  def perform(today: Date.current)
    previous = today.prev_month

    case MonthlyStatus::Adapters.repository.user_ids_with_open_months(up_to_month: previous.month, up_to_year: previous.year)
    in Solid::Success(user_ids:)
      user_ids.each { |user_id| MonthlyStatus::MonthlyClosingJob.perform_later(user_id:) }
    end
  end
end
