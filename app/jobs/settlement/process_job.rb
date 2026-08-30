class Settlement::ProcessJob < ApplicationJob
  include RetryableWithLogging

  queue_as :default

  def perform(user_id:, month:, year:, reference_date:)
    case Settlement.process(user_id:, month:, year:, reference_date:)
    in Solid::Success(failures:) if failures.any?
      Rails.logger.warn(
        "[settlement] items not settled user_id=#{user_id} month=#{month} year=#{year} " \
        "reference_date=#{reference_date} failures=#{failures.inspect}"
      )
    in Solid::Success then nil
    in Solid::Failure(type:)
      Rails.logger.error("[settlement] run failed user_id=#{user_id} month=#{month} year=#{year} type=#{type}")
    end
  end
end
