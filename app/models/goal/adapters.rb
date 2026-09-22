module Goal::Adapters
  extend Solid::Adapters::Configurable

  config.repository = Goal::Repository::Adapters::ActiveRecord

  def self.repository = config.repository
end
