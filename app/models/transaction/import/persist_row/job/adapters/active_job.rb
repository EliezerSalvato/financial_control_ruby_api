module Transaction::Import::PersistRow::Job::Adapters::ActiveJob
  include Core::Transaction::Import::PersistRow::Job::Interface
  extend self

  def start(user_id:, import_id:, row:)
    Transaction::Import::PersistRowJob.perform_later(user_id:, import_id:, row:)
  end
end
