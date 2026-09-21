class Category::Record < ApplicationRecord
  self.table_name = "categories"

  has_paper_trail

  belongs_to :user, class_name: "User::Record"
  has_many :goals, class_name: "Category::Goal::Record", foreign_key: :category_id, dependent: :destroy, inverse_of: :category

  def self.ransackable_attributes(_auth_object = nil)
    %w[name active]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end
end
