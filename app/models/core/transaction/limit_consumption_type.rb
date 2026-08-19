module Core::Transaction::LimitConsumptionType
  UPFRONT = "upfront"
  MONTHLY = "monthly"

  ALL = [ UPFRONT, MONTHLY ].freeze

  def self.default_for(payment_method:, recurrence_type:, limit_consumption_type:)
    return unless payment_method == Core::Transaction::PaymentMethod::CREDIT_CARD
    return limit_consumption_type if limit_consumption_type.present?

    UPFRONT if recurrence_type == Core::Transaction::RecurrenceType::ONE_TIME
  end
end
