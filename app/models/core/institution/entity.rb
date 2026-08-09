Core::Institution::Entity = Data.define(:id, :user_id, :name, :logo_key, :active) do
  def active? = active
end
