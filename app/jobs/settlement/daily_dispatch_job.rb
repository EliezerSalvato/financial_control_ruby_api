class Settlement::DailyDispatchJob < ApplicationJob
  queue_as :settlement

  def perform(date: Date.current)
    case Settlement.dispatch(date:)
    in Solid::Success then nil
    in Solid::Failure(type:) then raise RetryableError, type.to_s
    end
  end
end
