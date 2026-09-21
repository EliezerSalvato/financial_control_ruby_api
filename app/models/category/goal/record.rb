class Category::Goal::Record < ApplicationRecord
  self.table_name = "category_goals"

  has_paper_trail

  belongs_to :category, class_name: "Category::Record", foreign_key: :category_id, inverse_of: :goals
end
