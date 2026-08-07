Core::Tag::Entity = Data.define(:id, :user_id, :name, :color, :active) do
  def active? = active
end
