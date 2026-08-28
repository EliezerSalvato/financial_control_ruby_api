module MonthlyStatus::Adapters
  extend Solid::Adapters::Configurable

  config.repository = MonthlyStatus::Repository::Adapters::ActiveRecord

  def self.repository = config.repository
end
