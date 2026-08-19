module Core::Transaction::RecurrenceType
  ONE_TIME = "one_time"
  INSTALLMENT = "installment"
  RECURRING = "recurring"

  ALL = [ ONE_TIME, INSTALLMENT, RECURRING ].freeze

  def self.validate_compatibility_with_ends_on(errors, recurrence_type:, starts_on:, ends_on:)
    case recurrence_type
    when ONE_TIME
      errors.add(:ends_on, :present) if ends_on.present?
    when INSTALLMENT
      errors.add(:ends_on, :blank) if ends_on.blank?

      if starts_on.present? && ends_on.present?
        errors.add(:ends_on, :before_starts_on) if ends_on < starts_on
        count = Core::Transaction::Installments.calculate(recurrence_type:, starts_on:, ends_on:)
        errors.add(:ends_on, :invalid_installments_count) if count.nil? || count <= 1
      end
    when RECURRING
      errors.add(:ends_on, :before_starts_on) if starts_on.present? && ends_on.present? && ends_on < starts_on
    end
  end
end
