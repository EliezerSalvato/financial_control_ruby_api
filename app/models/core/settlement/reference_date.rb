module Core::Settlement::ReferenceDate
  extend self

  def for(monthly_status:, today:)
    month_start = Date.new(monthly_status.year, monthly_status.month, 1)

    return if month_start > today.beginning_of_month

    reference_date =
      if month_start == today.beginning_of_month
        today.yesterday
      else
        Date.new(monthly_status.year, monthly_status.month, -1)
      end

    return if reference_date < month_start

    reference_date
  end
end
