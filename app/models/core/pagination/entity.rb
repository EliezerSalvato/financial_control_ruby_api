Core::Pagination::Entity = Data.define(
  :page,
  :per_page,
  :count,
  :pages,
  :next_page,
  :prev_page
) do
  def as_json(*) = to_h
end
