module RetryableWithLogging
  extend ActiveSupport::Concern

  included do
    retry_on StandardError, attempts: 5, wait: :polynomially_longer do |job, error|
      Rails.logger.error(
        "[#{job.class.name}] exhausted retries arguments=#{job.arguments.inspect} " \
        "error=#{error.class}: #{error.message}"
      )
      Rails.logger.error(error.backtrace&.first(20)&.join("\n"))
    end
  end
end
