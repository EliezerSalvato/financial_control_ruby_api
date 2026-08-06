Core::User::Entity = Data.define(
  :id,
  :first_name,
  :last_name,
  :email,
  :verified,
  :active
) do
  def verified? = verified

  def active? = active
end
