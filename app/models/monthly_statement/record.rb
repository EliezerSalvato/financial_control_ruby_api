class MonthlyStatement::Record < ApplicationRecord
  self.primary_key = "id"
  self.inheritance_column = nil

  LISTING_SQL = File.read(File.expand_path("listing.sql", __dir__))

  attribute :id, :string
  attribute :kind, :string
  attribute :description, :string
  attribute :recurrence_type, :string
  attribute :payment_method, :string
  attribute :resource_id, :string
  attribute :resource_name, :string
  attribute :resource_brand, :string
  attribute :opening_date, :date
  attribute :closing_date, :date
  attribute :due_date, :date
  attribute :value, :decimal
  attribute :first_recurrence_on, :date
  attribute :current_recurrence_on, :date
  attribute :starts_on, :date
  attribute :ends_on, :date
  attribute :canceled_on, :date

  def self.for_period(user_id:, month:, year:)
    find_by_sql([ LISTING_SQL, { user_id:, month:, year: } ])
  end

  def readonly? = true

  def self.load_schema!
    @columns_hash = {}.freeze
  end
  private_class_method :load_schema!
end
