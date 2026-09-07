class CreditCard::InvoiceSettlement::Due::Record < ApplicationRecord
  self.primary_key = "credit_card_id"
  self.inheritance_column = nil

  LISTING_SQL = File.read(File.expand_path("../due_invoices.sql", __dir__))

  attribute :credit_card_id, :string
  attribute :credit_card_name, :string
  attribute :payment_account_id, :string
  attribute :opening_date, :date
  attribute :closing_date, :date
  attribute :due_date, :date
  attribute :total_value, :decimal

  def self.for_period(user_id:, month:, year:, reference_date:)
    find_by_sql([ LISTING_SQL, { user_id:, month:, year:, reference_date: } ])
  end

  def readonly? = true

  def self.load_schema!
    @columns_hash = {}.freeze
  end
  private_class_method :load_schema!
end
