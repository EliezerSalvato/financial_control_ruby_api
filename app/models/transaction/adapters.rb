module Transaction::Adapters
  extend Solid::Adapters::Configurable

  config.repository = Transaction::Repository::Adapters::ActiveRecord
  config.transaction_for_account_repository = Transaction::ForAccount::Repository::Adapters::ActiveRecord
  config.transaction_for_credit_card_repository = Transaction::ForCreditCard::Repository::Adapters::ActiveRecord
  config.transaction_for_transfer_between_accounts_repository = Transaction::ForTransferBetweenAccounts::Repository::Adapters::ActiveRecord
  config.recurrence_repository = Transaction::Recurrence::Repository::Adapters::ActiveRecord
  config.tagging_repository = Transaction::Tagging::Repository::Adapters::ActiveRecord
  config.settlement_repository = Transaction::Settlement::Repository::Adapters::ActiveRecord
  config.import_rule_repository = Transaction::Import::Rule::Repository::Adapters::ActiveRecord
  config.import_preview_row_job = Transaction::Import::PreviewRow::Job::Adapters::ActiveJob
  config.import_persist_row_job = Transaction::Import::PersistRow::Job::Adapters::ActiveJob

  def self.repository = config.repository
  def self.transaction_for_account_repository = config.transaction_for_account_repository
  def self.transaction_for_credit_card_repository = config.transaction_for_credit_card_repository
  def self.transaction_for_transfer_between_accounts_repository = config.transaction_for_transfer_between_accounts_repository
  def self.recurrence_repository = config.recurrence_repository
  def self.tagging_repository = config.tagging_repository
  def self.settlement_repository = config.settlement_repository
  def self.import_rule_repository = config.import_rule_repository
  def self.import_preview_row_job = config.import_preview_row_job
  def self.import_persist_row_job = config.import_persist_row_job
end
