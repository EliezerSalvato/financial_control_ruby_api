class Transaction::Import::PersistRowJob < ApplicationJob
  queue_as :transaction_import

  retry_on(StandardError, attempts: 5, wait: :polynomially_longer) { |job, _error| job.publish_error }

  def perform(user_id:, import_id:, row:)
    number = row[:row]

    case Transaction.import_row(user_id:, **row.to_h.symbolize_keys.except(:row))
    in Solid::Success(type: :ignored)
      broadcast.import_ignored(user_id:, import_id:, row: number)
    in Solid::Success(transaction:)
      broadcast.import_created(user_id:, import_id:, row: number, transaction_id: transaction.id)
    in Solid::Failure(type: :already_imported)
      broadcast.import_skipped(user_id:, import_id:, row: number)
    in Solid::Failure(input:)
      publish_error(input:)
    in Solid::Failure
      publish_error
    end
  end

  def publish_error(input: nil)
    arguments = self.arguments.first

    broadcast.error(
      user_id: arguments[:user_id], import_id: arguments[:import_id], stage: Transaction::Import::Broadcast::IMPORT, row: arguments[:row][:row], input:
    )
  end

  private

  def broadcast = Transaction::Import::Broadcast
end
