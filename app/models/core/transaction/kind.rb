module Core::Transaction::Kind
  INCOME = "income"
  EXPENSE = "expense"
  TRANSFER_BETWEEN_ACCOUNTS = "transfer_between_accounts"

  ALL = [ INCOME, EXPENSE, TRANSFER_BETWEEN_ACCOUNTS ].freeze
end
