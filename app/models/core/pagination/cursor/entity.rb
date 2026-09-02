Core::Pagination::Cursor::Entity = Data.define(:limit, :next_cursor, :has_more) do
  def as_json(*) = to_h
end
