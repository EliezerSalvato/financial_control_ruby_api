Core::User::Password::Reset::Entity = Data.define(
  :id,
  :user_id,
  :expires_at,
  :reset_at
) do
  def reset? = reset_at.present?
end
