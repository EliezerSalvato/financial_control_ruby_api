module Transaction::Repository::Adapters::ActiveRecord
  include Core::Transaction::Repository::Interface
  extend Solid::Output.mixin
  extend self

  def list(user:, filters:, sorting:, page:, per_page:)
    scope = user_transactions(user).includes(:recurrences)
    sorts = sorting.to_s.split(",").map(&:strip)
    query = scope.ransack(filters.merge(s: sorts))
    records, pagination = Pagination.paginate(query.result, page:, per_page:)

    Success(:transactions_listed, transactions: Transaction::Mapper.to_entities(records), pagination:)
  rescue Ransack::InvalidSearchError, ArgumentError, Pagy::OptionError
    Failure(:invalid_filters)
  end

    def find_by_id(user:, id:)
      record = user_transactions(user).find_by(id:)

      return Success(:transaction_found, transaction: Transaction::Mapper.to_entity(record)) if record.present?

      Failure(:transaction_not_found)
    end

    def exists_by_category_id?(user:, category_id:)
      user_transactions(user).exists?(category_id:)
    end

    def exists_by_institution_id?(user:, institution_id:)
      account_ids = Account::Record.where(user_id: user.id, institution_id:).select(:id)
      credit_card_ids = CreditCard::Record.where(user_id: user.id, institution_id:).select(:id)

      Transaction::ForAccount::Record.where(account_id: account_ids).exists? ||
        Transaction::ForCreditCard::Record.where(credit_card_id: credit_card_ids).exists? ||
        Transaction::ForTransferBetweenAccounts::Record.where(source_account_id: account_ids).exists? ||
        Transaction::ForTransferBetweenAccounts::Record.where(destination_account_id: account_ids).exists?
    end

    def exists_by_account_id?(user:, account_id:)
      transaction_ids = user_transactions(user).select(:id)

      Transaction::ForAccount::Record.where(transaction_id: transaction_ids, account_id:).exists? ||
        Transaction::ForTransferBetweenAccounts::Record.where(transaction_id: transaction_ids, source_account_id: account_id).exists? ||
        Transaction::ForTransferBetweenAccounts::Record.where(transaction_id: transaction_ids, destination_account_id: account_id).exists?
    end

    def exists_by_credit_card_id?(user:, credit_card_id:)
      transaction_ids = user_transactions(user).select(:id)

      Transaction::ForCreditCard::Record.where(transaction_id: transaction_ids, credit_card_id:).exists?
    end

  def create(user:, attributes:)
    record = user_transactions(user).create(create_attributes(attributes))

    return Success(:transaction_created, transaction: Transaction::Mapper.to_entity(record)) if record.persisted?

    Failure(
      :transaction_creation_failed,
      transaction: Transaction::Mapper.to_entity(record),
      errors: Transaction::Mapper.to_errors(record)
    )
  end

  def update(transaction:, attributes:)
    record = Transaction::Mapper.to_record(transaction)
    updated = record.update(update_attributes(attributes))

    return Success(:transaction_updated, transaction: Transaction::Mapper.to_entity(record)) if updated

    Failure(
      :transaction_update_failed,
      transaction: Transaction::Mapper.to_entity(record),
      errors: Transaction::Mapper.to_errors(record)
    )
  end

  def destroy(transaction:)
    record = Transaction::Mapper.to_record(transaction)

    return Success(:transaction_destroyed) if record.destroy

    Failure(:transaction_destruction_failed)
  end

  private

  def user_transactions(user)
    Transaction::Record.where(user_id: user.id)
  end

  def create_attributes(attributes)
    attributes.slice(
      :category_id,
      :description,
      :kind,
      :status,
      :payment_method,
      :recurrence_type,
      :installments_count,
      :ends_on
    )
  end

  def update_attributes(attributes)
    attributes.slice(
      :category_id,
      :description,
      :kind,
      :status,
      :payment_method,
      :recurrence_type,
      :installments_count,
      :ends_on,
      :canceled_on
    )
  end
end
