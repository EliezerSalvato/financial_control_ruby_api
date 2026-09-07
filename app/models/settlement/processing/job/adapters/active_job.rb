module Settlement::Processing::Job::Adapters::ActiveJob
  include Core::Settlement::Processing::Job::Interface
  extend self

  def start(user_id:, month:, year:, reference_date:)
    Settlement::ProcessJob.perform_later(user_id:, month:, year:, reference_date:)
  end
end
