module Tag::Adapters
  extend Solid::Adapters::Configurable

  config.repository = Tag::Repository::Adapters::ActiveRecord
  config.goal_repository = Tag::Goal::Repository::Adapters::ActiveRecord

  def self.repository = config.repository
  def self.goal_repository = config.goal_repository
end
