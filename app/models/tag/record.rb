class Tag::Record < ApplicationRecord
  self.table_name = "tags"

  has_paper_trail

  belongs_to :user, class_name: "User::Record"

  has_many :transaction_taggings, class_name: "Transaction::Tagging::Record", foreign_key: :tag_id, dependent: :destroy, inverse_of: :tag

  def self.ransackable_attributes(_auth_object = nil)
    %w[name active]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end
end
