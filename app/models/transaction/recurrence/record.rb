class Transaction::Recurrence::Record < ApplicationRecord
  self.table_name = "transaction_recurrences"

  has_paper_trail

  belongs_to :financial_transaction, class_name: "Transaction::Record", foreign_key: :transaction_id, inverse_of: :recurrences

  # Stored generated columns derived from starts_on (EXTRACT MONTH/YEAR).
  attr_readonly :month, :year
end
