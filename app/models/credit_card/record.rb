class CreditCard::Record < ApplicationRecord
  self.table_name = "credit_cards"

  has_paper_trail

  belongs_to :user, class_name: "User::Record"
  belongs_to :institution, class_name: "Institution::Record"
  belongs_to :default_payment_account, class_name: "Account::Record"

  def self.ransackable_attributes(_auth_object = nil)
    %w[
      name
      network
      active
      institution_id
      default_payment_account_id
      total_limit
      available_limit
      closing_day
      due_day
    ]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[institution default_payment_account]
  end
end
