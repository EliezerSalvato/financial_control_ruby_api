class MonthlyStatus::MonthlyDispatchJob < ApplicationJob
  queue_as :monthly_status

  def perform(date: Date.current)
    case MonthlyStatus.dispatch(date:)
    in Solid::Success then nil
    in Solid::Failure(type:) then raise RetryableError, type.to_s
    end
  end
end
