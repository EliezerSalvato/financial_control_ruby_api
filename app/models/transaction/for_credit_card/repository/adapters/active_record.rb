module Transaction::ForCreditCard::Repository::Adapters::ActiveRecord
  include Core::Transaction::ForCreditCard::Repository::Interface
  extend Solid::Output.mixin
  extend self

  def create(transaction:, credit_card_id:, limit_consumption_type:)
    record = Transaction::ForCreditCard::Record.create(
      transaction_id: transaction.id,
      credit_card_id:,
      limit_consumption_type:
    )

    return Success(:for_credit_card_created) if record.persisted?

    Failure(:for_credit_card_creation_failed, errors: Transaction::ForCreditCard::Mapper.to_errors(record))
  end

  def upsert(transaction:, credit_card_id:, limit_consumption_type:)
    record = Transaction::ForCreditCard::Record.find_or_initialize_by(transaction_id: transaction.id)
    record.credit_card_id = credit_card_id if credit_card_id.present?
    record.limit_consumption_type = limit_consumption_type if limit_consumption_type.present?

    return Success(:for_credit_card_upserted) if record.save

    Failure(:for_credit_card_upsert_failed, errors: Transaction::ForCreditCard::Mapper.to_errors(record))
  end

  def destroy(transaction:)
    record = Transaction::ForCreditCard::Record.find_by(transaction_id: transaction.id)

    return Success(:for_credit_card_destroyed) if record.nil? || record.destroy

    Failure(:for_credit_card_destruction_failed, errors: Transaction::ForCreditCard::Mapper.to_errors(record))
  end
end
