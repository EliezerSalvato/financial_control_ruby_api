module Tag::Adapters
  extend Solid::Adapters::Configurable

  config.repository = Tag::Repository::Adapters::ActiveRecord

  def self.repository = config.repository
end
