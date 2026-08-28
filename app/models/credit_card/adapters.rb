module CreditCard::Adapters
  extend Solid::Adapters::Configurable

  config.repository = CreditCard::Repository::Adapters::ActiveRecord
  config.invoice_settlement_repository = CreditCard::InvoiceSettlement::Repository::Adapters::ActiveRecord

  def self.repository = config.repository
  def self.invoice_settlement_repository = config.invoice_settlement_repository
end
