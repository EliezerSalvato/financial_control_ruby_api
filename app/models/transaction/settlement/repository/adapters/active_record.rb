module Transaction::Settlement::Repository::Adapters::ActiveRecord
  include Core::Transaction::Settlement::Repository::Interface
  extend Solid::Output.mixin
  extend self

  def create(transaction_id:, occurred_on:, settled_on:, value:, installment_number:, account_id: nil, source_account_id: nil, destination_account_id: nil, limit_consumed: nil)
    ApplicationRecord.transaction(requires_new: true) do
      record = Transaction::Settlement::Record.create!(
        transaction_id:,
        occurred_on:,
        settled_on:,
        value:,
        installment_number:
      )
      create_dependencies!(record, account_id:, source_account_id:, destination_account_id:, limit_consumed:)

      Success(:transaction_settlement_created, settlement: Transaction::Settlement::Mapper.to_entity(record))
    end
  rescue ActiveRecord::RecordNotUnique
    Success(:already_settled, settlement: Transaction::Settlement::Mapper.to_entity(find_existing(transaction_id:, occurred_on:)))
  rescue ActiveRecord::RecordInvalid => e
    Failure(:transaction_settlement_creation_failed, errors: Transaction::Settlement::Mapper.to_errors(e.record))
  end

  def list_for_month(user:, month:, year:, type: nil)
    period = Date.new(year, month, 1)..Date.new(year, month, 1).end_of_month

    records = apply_type_filter(
      Transaction::Settlement::Record
        .joins(:financial_transaction)
        .includes(
          :for_account,
          :for_transfer_between_accounts,
          financial_transaction: [ :for_credit_card ]
        )
        .where(transactions: { user_id: user.id }, occurred_on: period),
      type
    ).order("transaction_settlements.occurred_on ASC, transactions.description ASC, transaction_settlements.id ASC")

    Success(:settled_transactions_listed, settled_transactions: Transaction::Settled::Mapper.to_entities(records))
  end

  def settled_keys(transaction_ids:, occurred_on_range:)
    keys = Transaction::Settlement::Record
      .where(transaction_id: transaction_ids, occurred_on: occurred_on_range)
      .pluck(:transaction_id, :occurred_on)

    Success(:transaction_settlements_listed, keys:)
  end

  def count_for(transaction_id:)
    Success(:transaction_settlements_counted, count: Transaction::Settlement::Record.where(transaction_id:).count)
  end

  private

  def apply_type_filter(records, type)
    case type
    when Core::Transaction::Settled::Type::ACCOUNT
      records.where.associated(:for_account)
    when Core::Transaction::Settled::Type::CREDIT_CARD
      records.where.associated(:for_credit_card)
    when Core::Transaction::Settled::Type::TRANSFER_BETWEEN_ACCOUNTS
      records.where.associated(:for_transfer_between_accounts)
    else
      records
    end
  end

  def create_dependencies!(record, account_id:, source_account_id:, destination_account_id:, limit_consumed:)
    if account_id.present?
      record.create_for_account!(account_id:)
    elsif source_account_id.present? && destination_account_id.present?
      record.create_for_transfer_between_accounts!(source_account_id:, destination_account_id:)
    elsif !limit_consumed.nil?
      record.create_for_credit_card!(limit_consumed:)
    end
  end

  def find_existing(transaction_id:, occurred_on:)
    Transaction::Settlement::Record
      .includes(:for_account, :for_transfer_between_accounts, :for_credit_card)
      .find_by!(transaction_id:, occurred_on:)
  end
end
