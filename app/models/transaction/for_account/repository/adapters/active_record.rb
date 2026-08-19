module Transaction::ForAccount::Repository::Adapters::ActiveRecord
  include Core::Transaction::ForAccount::Repository::Interface
  extend Solid::Output.mixin
  extend self

  def create(transaction:, account_id:)
    record = Transaction::ForAccount::Record.create(
      transaction_id: transaction.id,
      account_id:
    )

    return Success(:for_account_created) if record.persisted?

    Failure(:for_account_creation_failed, errors: Transaction::ForAccount::Mapper.to_errors(record))
  end

  def upsert(transaction:, account_id:)
    record = Transaction::ForAccount::Record.find_or_initialize_by(transaction_id: transaction.id)
    record.account_id = account_id if account_id.present?

    return Success(:for_account_upserted) if record.save

    Failure(:for_account_upsert_failed, errors: Transaction::ForAccount::Mapper.to_errors(record))
  end

  def destroy(transaction:)
    record = Transaction::ForAccount::Record.find_by(transaction_id: transaction.id)

    return Success(:for_account_destroyed) if record.nil? || record.destroy

    Failure(:for_account_destruction_failed, errors: Transaction::ForAccount::Mapper.to_errors(record))
  end
end
