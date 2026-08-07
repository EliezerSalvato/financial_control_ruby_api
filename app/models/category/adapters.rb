module Category::Adapters
  extend Solid::Adapters::Configurable

  config.repository = Category::Repository::Adapters::ActiveRecord

  def self.repository = config.repository
end
