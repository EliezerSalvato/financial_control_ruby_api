module Transaction::ForTransferBetweenAccounts::Repository::Adapters::ActiveRecord
  include Core::Transaction::ForTransferBetweenAccounts::Repository::Interface
  extend Solid::Output.mixin
  extend self

  def create(transaction:, source_account_id:, destination_account_id:)
    record = Transaction::ForTransferBetweenAccounts::Record.create(
      transaction_id: transaction.id,
      source_account_id:,
      destination_account_id:
    )

    return Success(:for_transfer_between_accounts_created) if record.persisted?

    Failure(
      :for_transfer_between_accounts_creation_failed,
      errors: Transaction::ForTransferBetweenAccounts::Mapper.to_errors(record)
    )
  end

  def upsert(transaction:, source_account_id:, destination_account_id:)
    record = Transaction::ForTransferBetweenAccounts::Record.find_or_initialize_by(transaction_id: transaction.id)
    record.source_account_id = source_account_id if source_account_id.present?
    record.destination_account_id = destination_account_id if destination_account_id.present?

    return Success(:for_transfer_between_accounts_upserted) if record.save

    Failure(
      :for_transfer_between_accounts_upsert_failed,
      errors: Transaction::ForTransferBetweenAccounts::Mapper.to_errors(record)
    )
  end

  def destroy(transaction:)
    record = Transaction::ForTransferBetweenAccounts::Record.find_by(transaction_id: transaction.id)

    return Success(:for_transfer_between_accounts_destroyed) if record.nil? || record.destroy

    Failure(
      :for_transfer_between_accounts_destruction_failed,
      errors: Transaction::ForTransferBetweenAccounts::Mapper.to_errors(record)
    )
  end
end
