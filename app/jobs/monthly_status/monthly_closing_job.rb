class MonthlyStatus::MonthlyClosingJob < ApplicationJob
  queue_as :monthly_status

  def perform(user_id:, date: Date.current)
    case MonthlyStatus.close_open_months(user_id:, date:)
    in Solid::Success then nil
    in Solid::Failure(type:) then raise RetryableError, type.to_s
    end
  end
end
