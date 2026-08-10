module CreditCard::Adapters
  extend Solid::Adapters::Configurable

  config.repository = CreditCard::Repository::Adapters::ActiveRecord

  def self.repository = config.repository
end
