class Transaction::Tagging::Record < ApplicationRecord
  self.table_name = "transaction_tags"

  has_paper_trail

  belongs_to :financial_transaction, class_name: "Transaction::Record", foreign_key: :transaction_id, inverse_of: :taggings
  belongs_to :tag, class_name: "Tag::Record"
end
