Core::User::Email::Confirmation::Entity = Data.define(
  :id,
  :user_id,
  :old_email,
  :new_email,
  :expires_at,
  :confirmed_at
) do
  def confirmed? = confirmed_at.present?
end
