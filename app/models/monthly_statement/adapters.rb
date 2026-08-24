module MonthlyStatement::Adapters
  extend Solid::Adapters::Configurable

  config.repository = MonthlyStatement::Repository::Adapters::ActiveRecord

  def self.repository = config.repository
end
