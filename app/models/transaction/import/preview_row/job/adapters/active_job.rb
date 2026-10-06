module Transaction::Import::PreviewRow::Job::Adapters::ActiveJob
  include Core::Transaction::Import::PreviewRow::Job::Interface
  extend self

  def start(user_id:, import_id:, row:, data:, occurrence:, defaults:)
    Transaction::Import::PreviewRowJob.perform_later(user_id:, import_id:, row:, data:, occurrence:, defaults:)
  end
end
