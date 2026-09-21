Core::Tag::Goal::Entity = Data.define(:id, :month, :year, :value) do
  def starts_on = Date.new(year, month, 1)
end
