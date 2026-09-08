Core::Transaction::Settled::Entity = Data.define(
  :id,
  :transaction_id,
  :category_id,
  :description,
  :kind,
  :status,
  :payment_method,
  :recurrence_type,
  :installments_count,
  :ends_on,
  :canceled_on,
  :occurred_on,
  :settled_on,
  :value,
  :installment_number,
  :account_id,
  :credit_card_id,
  :limit_consumption_type,
  :source_account_id,
  :destination_account_id
) do
  def initialize(
    id:,
    transaction_id:,
    category_id:,
    description:,
    kind:,
    status:,
    payment_method:,
    recurrence_type:,
    installments_count:,
    ends_on:,
    canceled_on:,
    occurred_on:,
    settled_on:,
    value:,
    installment_number:,
    account_id: nil,
    credit_card_id: nil,
    limit_consumption_type: nil,
    source_account_id: nil,
    destination_account_id: nil
  )
    super
  end

  def account_payment? = account_id.present?

  def credit_card_payment? = credit_card_id.present?

  def transfer_between_accounts? = source_account_id.present? && destination_account_id.present?
end
