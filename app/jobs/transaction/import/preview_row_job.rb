class Transaction::Import::PreviewRowJob < ApplicationJob
  queue_as :transaction_import

  retry_on(StandardError, attempts: 5, wait: :polynomially_longer) { |job, _error| job.publish_error }

  def perform(user_id:, import_id:, row:, data:, occurrence:, defaults:)
    case Transaction.preview_import_row(user_id:, row:, data:, occurrence:, defaults:)
    in Solid::Success(row: preview)
      broadcast.preview_processed(user_id:, import_id:, row:, data: preview)
    in Solid::Failure(type: :already_imported | :skipped_by_rule)
      broadcast.preview_skipped(user_id:, import_id:, row:)
    in Solid::Failure(input:)
      publish_error(input:)
    in Solid::Failure
      publish_error
    end
  end

  def publish_error(input: nil)
    arguments = self.arguments.first

    broadcast.error(
      user_id: arguments[:user_id], import_id: arguments[:import_id], stage: Transaction::Import::Broadcast::PREVIEW, row: arguments[:row], input:
    )
  end

  private

  def broadcast = Transaction::Import::Broadcast
end
