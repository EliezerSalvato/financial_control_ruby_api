module Core::Transaction::Settled::Type
  ACCOUNT = "account"
  CREDIT_CARD = "credit_card"
  TRANSFER_BETWEEN_ACCOUNTS = "transfer_between_accounts"

  ALL = [ ACCOUNT, CREDIT_CARD, TRANSFER_BETWEEN_ACCOUNTS ].freeze
end
