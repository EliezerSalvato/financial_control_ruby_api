Core::CreditCard::Entity = Data.define(
  :id,
  :user_id,
  :institution_id,
  :default_payment_account_id,
  :name,
  :total_limit,
  :available_limit,
  :closing_day,
  :due_day,
  :network,
  :active
) do
  def active? = active
end
