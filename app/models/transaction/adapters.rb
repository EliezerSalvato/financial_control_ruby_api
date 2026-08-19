module Transaction::Adapters
  extend Solid::Adapters::Configurable

  config.repository = Transaction::Repository::Adapters::ActiveRecord
  config.transaction_for_account_repository = Transaction::ForAccount::Repository::Adapters::ActiveRecord
  config.transaction_for_credit_card_repository = Transaction::ForCreditCard::Repository::Adapters::ActiveRecord
  config.transaction_for_transfer_between_accounts_repository = Transaction::ForTransferBetweenAccounts::Repository::Adapters::ActiveRecord
  config.recurrence_repository = Transaction::Recurrence::Repository::Adapters::ActiveRecord
  config.tagging_repository = Transaction::Tagging::Repository::Adapters::ActiveRecord

  def self.repository = config.repository
  def self.transaction_for_account_repository = config.transaction_for_account_repository
  def self.transaction_for_credit_card_repository = config.transaction_for_credit_card_repository
  def self.transaction_for_transfer_between_accounts_repository = config.transaction_for_transfer_between_accounts_repository
  def self.recurrence_repository = config.recurrence_repository
  def self.tagging_repository = config.tagging_repository
end
