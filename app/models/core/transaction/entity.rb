Core::Transaction::Entity = Data.define(
  :id,
  :user_id,
  :category_id,
  :description,
  :kind,
  :status,
  :payment_method,
  :recurrence_type,
  :installments_count,
  :ends_on,
  :canceled_on,
  :account_id,
  :credit_card_id,
  :limit_consumption_type,
  :source_account_id,
  :destination_account_id,
  :tag_ids,
  :recurrences
) do
  def initialize(
    id:,
    user_id:,
    category_id:,
    description:,
    kind:,
    status:,
    payment_method:,
    recurrence_type:,
    installments_count:,
    ends_on:,
    canceled_on:,
    recurrences:,
    tag_ids: nil,
    account_id: nil,
    credit_card_id: nil,
    limit_consumption_type: nil,
    source_account_id: nil,
    destination_account_id: nil
  )
    super
  end

  def income? = kind == Core::Transaction::Kind::INCOME

  def expense? = kind == Core::Transaction::Kind::EXPENSE

  def transfer_between_accounts? = kind == Core::Transaction::Kind::TRANSFER_BETWEEN_ACCOUNTS

  def credit_card_payment? = payment_method == Core::Transaction::PaymentMethod::CREDIT_CARD

  def account_payment? = Core::Transaction::PaymentMethod::ACCOUNT_BASED.include?(payment_method)

  def pending? = status == Core::Transaction::Status::PENDING

  def active? = status == Core::Transaction::Status::ACTIVE

  def completed? = status == Core::Transaction::Status::COMPLETED

  def canceled? = status == Core::Transaction::Status::CANCELED

  def completed_or_canceled? = completed? || canceled?

  def current_value = value_on(Date.current)

  def value_on(date)
    as_of_month = date.beginning_of_month

    recurrences
      .select { |recurrence| recurrence.starts_on.beginning_of_month <= as_of_month }
      .max_by(&:starts_on)
      &.value || recurrences.min_by(&:starts_on)&.value
  end
end
