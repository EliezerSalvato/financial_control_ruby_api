module Settlement::Adapters
  extend Solid::Adapters::Configurable

  config.processing_job = Settlement::Processing::Job::Adapters::ActiveJob

  def self.processing_job = config.processing_job
end
