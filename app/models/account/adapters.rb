module Account::Adapters
  extend Solid::Adapters::Configurable

  config.repository = Account::Repository::Adapters::ActiveRecord

  def self.repository = config.repository
end
