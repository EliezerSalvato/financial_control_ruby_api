module Core::Transaction::Installments
  extend self

  def calculate(recurrence_type:, starts_on:, ends_on:)
    return if recurrence_type != Core::Transaction::RecurrenceType::INSTALLMENT
    return if starts_on.blank? || ends_on.blank?

    ((ends_on.year * 12) + ends_on.month) - ((starts_on.year * 12) + starts_on.month) + 1
  end
end
