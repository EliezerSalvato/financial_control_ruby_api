class Goal::Record < ApplicationRecord
  self.primary_key = "id"
  self.inheritance_column = nil

  LISTING_SQL = File.read(File.expand_path("listing.sql", __dir__))
                    .sub("__STATEMENTS_SQL__", File.read(File.expand_path("../monthly_statement/listing.sql", __dir__)))
                    .sub("__TRANSFERS_SQL__", File.read(File.expand_path("../monthly_statement/listing_transfers.sql", __dir__)))

  attribute :id, :string
  attribute :kind, :string
  attribute :description, :string
  attribute :recurrence_type, :string
  attribute :value, :decimal
  attribute :first_recurrence_on, :date
  attribute :current_recurrence_on, :date
  attribute :ends_on, :date
  attribute :category_id, :string
  attribute :tag_ids, :string, array: true

  def self.for_period(user_id:, month:, year:)
    find_by_sql([ LISTING_SQL, { user_id:, month:, year:, statuses: nil, on: nil } ])
  end

  def readonly? = true

  def self.load_schema!
    @columns_hash = {}.freeze
  end
  private_class_method :load_schema!
end
