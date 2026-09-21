module Category::Adapters
  extend Solid::Adapters::Configurable

  config.repository = Category::Repository::Adapters::ActiveRecord
  config.goal_repository = Category::Goal::Repository::Adapters::ActiveRecord

  def self.repository = config.repository
  def self.goal_repository = config.goal_repository
end
