module Core::Transaction::LimitConsumptionType
  UPFRONT = "upfront"
  MONTHLY = "monthly"

  ALL = [ UPFRONT, MONTHLY ].freeze

  def self.default_for(payment_method:, recurrence_type:, limit_consumption_type:)
    return unless payment_method == Core::Transaction::PaymentMethod::CREDIT_CARD

    case recurrence_type
    when Core::Transaction::RecurrenceType::ONE_TIME
      UPFRONT
    when Core::Transaction::RecurrenceType::RECURRING
      MONTHLY
    else
      limit_consumption_type
    end
  end
end
