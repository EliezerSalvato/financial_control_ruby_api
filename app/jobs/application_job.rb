class ApplicationJob < ActiveJob::Base
  class RetryableError < StandardError; end

  retry_on StandardError, attempts: 5, wait: :polynomially_longer

  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no longer available
  # discard_on ActiveJob::DeserializationError
end
