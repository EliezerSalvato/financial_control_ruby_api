module MonthlyStatus::Closing::Job::Adapters::ActiveJob
  include Core::MonthlyStatus::Closing::Job::Interface
  extend self

  def start(user_id:, date:)
    MonthlyStatus::MonthlyClosingJob.perform_later(user_id:, date:)
  end

  def schedule(user_id:, date:, wait_until:)
    MonthlyStatus::MonthlyClosingJob.set(wait_until:).perform_later(user_id:, date:)
  end
end
