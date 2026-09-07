class Settlement::ProcessJob < ApplicationJob
  queue_as :settlement

  VALIDATION_FAILURES = %i[
    invalid_input
    previous_month_open
    later_month_closed
  ].freeze

  def perform(user_id:, month:, year:, reference_date:)
    case Settlement.process(user_id:, month:, year:, reference_date:)
    in Solid::Success then nil
    in Solid::Failure(type:) if VALIDATION_FAILURES.include?(type) then nil
    in Solid::Failure(type:) then raise RetryableError, type.to_s
    end
  end
end
