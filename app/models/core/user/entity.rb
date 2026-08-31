Core::User::Entity = Data.define(
  :id,
  :first_name,
  :last_name,
  :email,
  :verified,
  :active,
  :configs
) do
  def verified? = verified

  def active? = active
end
