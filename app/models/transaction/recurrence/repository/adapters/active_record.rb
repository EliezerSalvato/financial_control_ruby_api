module Transaction::Recurrence::Repository::Adapters::ActiveRecord
  include Core::Transaction::Recurrence::Repository::Interface
  extend Solid::Output.mixin
  extend self

  def create(transaction:, starts_on:, value:)
    record = Transaction::Recurrence::Record.create(
      transaction_id: transaction.id,
      starts_on:,
      value:
    )

    return Success(:recurrence_created, recurrence: Transaction::Recurrence::Mapper.to_entity(record)) if record.persisted?

    Failure(:recurrence_creation_failed, errors: Transaction::Recurrence::Mapper.to_errors(record))
  end

  def find_by_starts_on(transaction:, starts_on:)
    record = Transaction::Recurrence::Record.find_by(transaction_id: transaction.id, month: starts_on.month, year: starts_on.year)

    return Success(:recurrence_found, recurrence: Transaction::Recurrence::Mapper.to_entity(record)) if record.present?

    Failure(:recurrence_not_found)
  end

  def find_latest(transaction:)
    record = Transaction::Recurrence::Record.where(transaction_id: transaction.id).order(starts_on: :desc).first

    return Success(:recurrence_found, recurrence: Transaction::Recurrence::Mapper.to_entity(record)) if record.present?

    Failure(:recurrence_not_found)
  end

  def update(recurrence:, attributes:)
    record = Transaction::Recurrence::Mapper.to_record(recurrence)
    updated = record.update(attributes.compact)

    return Success(:recurrence_updated, recurrence: Transaction::Recurrence::Mapper.to_entity(record)) if updated

    Failure(:recurrence_update_failed, errors: Transaction::Recurrence::Mapper.to_errors(record))
  end

  def destroy_after(transaction:, starts_on:)
    next_month_start = Date.new(starts_on.year, starts_on.month, 1).next_month
    records = Transaction::Recurrence::Record.where(transaction_id: transaction.id, starts_on: next_month_start..)

    records.each do |record|
      next if record.destroy

      return Failure(:recurrence_destruction_failed, errors: Transaction::Recurrence::Mapper.to_errors(record))
    end

    Success(:recurrences_destroyed)
  end
end
