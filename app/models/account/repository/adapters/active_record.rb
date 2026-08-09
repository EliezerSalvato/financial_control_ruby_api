module Account::Repository::Adapters::ActiveRecord
  include Core::Account::Repository::Interface
  extend Solid::Output.mixin
  extend self

  def list(user:, filters:, sorting:, page:, per_page:)
    scope = user_accounts(user)
    sorts = sorting.to_s.split(",").map(&:strip)
    query = scope.ransack(filters.merge(s: sorts))
    records, pagination = Pagination.paginate(query.result, page:, per_page:)

    Success(:accounts_listed, accounts: Account::Mapper.to_entities(records), pagination:)
  rescue Ransack::InvalidSearchError, ArgumentError, Pagy::OptionError
    Failure(:invalid_filters)
  end

  def find_by_id(user:, id:)
    account = user_accounts(user).find_by(id:)

    return Success(:account_found, account: Account::Mapper.to_entity(account)) if account.present?

    Failure(:account_not_found)
  end

  def exists?(user:, name:, excluding_id: nil)
    scope = user_accounts(user).where("LOWER(name) = LOWER(?)", name)
    scope = scope.where.not(id: excluding_id) if excluding_id.present?

    scope.exists?
  end

  def create(user:, attributes:)
    account = user_accounts(user).create(attributes)

    return Success(:account_created, account: Account::Mapper.to_entity(account)) if account.persisted?

    Failure(:account_creation_failed, account: Account::Mapper.to_entity(account), errors: Account::Mapper.to_errors(account))
  end

  def update(account:, attributes:)
    record = Account::Mapper.to_record(account)
    updated = record.update(attributes)

    return Success(:account_updated, account: Account::Mapper.to_entity(record)) if updated

    Failure(:account_update_failed, account: Account::Mapper.to_entity(record), errors: Account::Mapper.to_errors(record))
  end

  def destroy(account:)
    record = Account::Mapper.to_record(account)

    return Success(:account_destroyed) if record.destroy

    Failure(:account_destruction_failed)
  end

  private

  def user_accounts(user)
    Account::Record.where(user_id: user.id)
  end
end
