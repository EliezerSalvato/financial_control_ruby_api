class Category::Record < ApplicationRecord
  self.table_name = "categories"

  has_paper_trail

  belongs_to :user, class_name: "User::Record"

  def self.ransackable_attributes(_auth_object = nil)
    %w[name active]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end
end
