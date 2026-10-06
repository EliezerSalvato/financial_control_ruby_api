class Transaction::Import::Rule::Record < ApplicationRecord
  self.table_name = "transaction_import_rules"

  has_paper_trail

  belongs_to :user, class_name: "User::Record"
  has_many :effects,
           -> { order(:position) },
           class_name: "Transaction::Import::Rule::Effect::Record",
           foreign_key: :import_rule_id,
           inverse_of: :import_rule,
           dependent: :destroy

  enum :match_type, {
    contains: "contains",
    regex: "regex"
  }, validate: true

  enum :target_column, {
    title: "title",
    description: "description",
    both: "both"
  }, prefix: :target, validate: true

  def self.ransackable_attributes(_auth_object = nil)
    %w[name active match_type target_column position]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end
end
