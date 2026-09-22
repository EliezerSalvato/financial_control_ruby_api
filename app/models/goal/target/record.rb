class Goal::Target::Record < ApplicationRecord
  self.primary_key = "id"
  self.inheritance_column = nil

  LISTING_SQL = File.read(File.expand_path("../listing_targets.sql", __dir__))

  attribute :id, :string
  attribute :kind, :string
  attribute :name, :string
  attribute :color, :string
  attribute :value, :decimal

  def self.for_period(user_id:, month:, year:)
    find_by_sql([ LISTING_SQL, { user_id:, month:, year: } ])
  end

  def readonly? = true

  def self.load_schema!
    @columns_hash = {}.freeze
  end
  private_class_method :load_schema!
end
