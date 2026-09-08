class Institution::Record < ApplicationRecord
  self.table_name = "institutions"

  has_paper_trail

  belongs_to :user, class_name: "User::Record"
  has_many :credit_cards, class_name: "CreditCard::Record", foreign_key: :institution_id, dependent: :destroy
  has_many :accounts, class_name: "Account::Record", foreign_key: :institution_id, dependent: :destroy

  def self.ransackable_attributes(_auth_object = nil)
    %w[name active]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end
end
