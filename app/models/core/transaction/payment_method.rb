module Core::Transaction::PaymentMethod
  PIX = "pix"
  DEBIT = "debit"
  CREDIT_CARD = "credit_card"
  TED = "ted"
  DOC = "doc"
  DEPOSIT = "deposit"
  CASH = "cash"
  BOLETO = "boleto"

  ALL = [ PIX, DEBIT, CREDIT_CARD, TED, DOC, DEPOSIT, CASH, BOLETO ].freeze
  INCOME = [ PIX, TED, DOC, DEPOSIT, CASH, BOLETO ].freeze
  EXPENSE = [ PIX, DEBIT, CREDIT_CARD, TED, DOC, DEPOSIT, CASH, BOLETO ].freeze
  ACCOUNT_BASED = [ PIX, DEBIT, TED, DOC, DEPOSIT, CASH, BOLETO ].freeze

  def self.validate_compatibility_with_kind(errors, kind:, payment_method:)
    case kind
    when Core::Transaction::Kind::TRANSFER_BETWEEN_ACCOUNTS
      errors.add(:payment_method, :present) if payment_method.present?
    when Core::Transaction::Kind::INCOME
      if payment_method.blank?
        errors.add(:payment_method, :blank)
      elsif Core::Transaction::PaymentMethod::INCOME.exclude?(payment_method)
        errors.add(:payment_method, :invalid_for_kind)
      end
    when Core::Transaction::Kind::EXPENSE
      if payment_method.blank?
        errors.add(:payment_method, :blank)
      elsif Core::Transaction::PaymentMethod::EXPENSE.exclude?(payment_method)
        errors.add(:payment_method, :invalid_for_kind)
      end
    end
  end
end
