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
  :allow_negative_available_limit,
  :active
) do
  def active? = active

  def allow_negative_available_limit? = allow_negative_available_limit
end
