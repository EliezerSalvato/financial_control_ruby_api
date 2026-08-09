module Institution::Adapters
  extend Solid::Adapters::Configurable

  config.repository = Institution::Repository::Adapters::ActiveRecord

  def self.repository = config.repository
end
