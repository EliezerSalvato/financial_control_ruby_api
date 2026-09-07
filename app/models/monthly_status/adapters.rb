module MonthlyStatus::Adapters
  extend Solid::Adapters::Configurable

  config.repository = MonthlyStatus::Repository::Adapters::ActiveRecord
  config.closing_job = MonthlyStatus::Closing::Job::Adapters::ActiveJob

  def self.repository = config.repository
  def self.closing_job = config.closing_job
end
