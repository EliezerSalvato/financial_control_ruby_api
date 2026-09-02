module Notification::Adapters
  extend Solid::Adapters::Configurable

  config.repository = Notification::Repository::Adapters::ActiveRecord

  def self.repository = config.repository
end
