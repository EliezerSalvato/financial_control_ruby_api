Core::Account::Entity = Data.define(
  :id,
  :user_id,
  :institution_id,
  :name,
  :kind,
  :bank_account_type,
  :current_balance,
  :color,
  :active
) do
  def active? = active

  def bank_account? = kind == Core::Account::Kind::BANK_ACCOUNT

  def cash? = kind == Core::Account::Kind::CASH
end
