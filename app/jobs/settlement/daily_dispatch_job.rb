class Settlement::DailyDispatchJob < ApplicationJob
  include RetryableWithLogging

  queue_as :default

  def perform(today: Date.current)
    case MonthlyStatus::Adapters.repository.list_open(up_to_month: today.month, up_to_year: today.year)
    in Solid::Success(monthly_statuses:)
      open_keys = monthly_statuses.map { |monthly_status| [ monthly_status.user_id, monthly_status.year, monthly_status.month ] }.to_set

      monthly_statuses.each do |monthly_status|
        next if previous_month_open?(monthly_status, open_keys)
        next if later_month_closed?(monthly_status)

        reference_date = Core::Settlement::ReferenceDate.for(monthly_status:, today:) or next

        Settlement::ProcessJob.perform_later(
          user_id: monthly_status.user_id,
          month: monthly_status.month,
          year: monthly_status.year,
          reference_date:
        )
      end
    end
  end

  private

  def previous_month_open?(monthly_status, open_keys)
    previous = Date.new(monthly_status.year, monthly_status.month, 1).prev_month

    open_keys.include?([ monthly_status.user_id, previous.year, previous.month ])
  end

  def later_month_closed?(monthly_status)
    MonthlyStatus::Adapters.repository.exists_closed_after?(
      user_id: monthly_status.user_id,
      month: monthly_status.month,
      year: monthly_status.year
    )
  end
end
