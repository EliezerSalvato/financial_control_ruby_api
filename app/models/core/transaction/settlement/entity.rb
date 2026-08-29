Core::Transaction::Settlement::Entity = Data.define(
  :id,
  :transaction_id,
  :occurred_on,
  :settled_on,
  :value,
  :installment_number,
  :account_id,
  :source_account_id,
  :destination_account_id,
  :limit_consumed,
  :credit_card_invoice_settlement_id
) do
  def initialize(
    id:,
    transaction_id:,
    occurred_on:,
    settled_on:,
    value:,
    installment_number:,
    account_id: nil,
    source_account_id: nil,
    destination_account_id: nil,
    limit_consumed: nil,
    credit_card_invoice_settlement_id: nil
  )
    super
  end

  def for_account? = account_id.present?

  def for_transfer_between_accounts? = source_account_id.present? && destination_account_id.present?

  def for_credit_card? = !limit_consumed.nil?
end
