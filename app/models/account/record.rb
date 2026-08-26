class Account::Record < ApplicationRecord
  self.table_name = "accounts"

  has_paper_trail

  belongs_to :user, class_name: "User::Record"
  belongs_to :institution, class_name: "Institution::Record", optional: true

  enum :kind, {
    bank_account: "bank_account",
    cash: "cash"
  }, validate: true

  enum :bank_account_type, {
    checking: "checking",
    savings: "savings",
    investment: "investment",
    salary: "salary"
  }, validate: { allow_nil: true }

  def self.ransackable_attributes(_auth_object = nil)
    %w[name kind bank_account_type allow_negative_balance active institution_id current_balance]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[institution]
  end
end
