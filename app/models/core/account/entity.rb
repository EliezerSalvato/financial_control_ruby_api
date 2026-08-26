Core::Account::Entity = Data.define(
  :id,
  :user_id,
  :institution_id,
  :name,
  :kind,
  :bank_account_type,
  :current_balance,
  :color,
  :allow_negative_balance,
  :active
) do
  def active? = active

  def allow_negative_balance? = allow_negative_balance

  def bank_account? = kind == Core::Account::Kind::BANK_ACCOUNT

  def cash? = kind == Core::Account::Kind::CASH
end
