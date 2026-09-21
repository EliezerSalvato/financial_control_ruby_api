class Tag::Goal::Record < ApplicationRecord
  self.table_name = "tag_goals"

  has_paper_trail

  belongs_to :tag, class_name: "Tag::Record", foreign_key: :tag_id, inverse_of: :goals
end
