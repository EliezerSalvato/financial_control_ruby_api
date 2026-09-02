require "pagy"

module Pagination
  include Core::Pagination::Interface
  extend self

  def paginate(collection, page:, per_page:)
    count = collection.count(:all)
    pagy = Pagy::Offset.new(count:, page:, limit: per_page)
    records = pagy.records(collection)

    [ records, meta(pagy) ]
  end

  def paginate_by_cursor(collection, after:, limit:)
    raise ArgumentError, "invalid cursor" if after.present? && Pagy::Keyset.decode(after).nil?

    pagy = Pagy::Keyset.new(collection, page: after, limit:)
    next_cursor = pagy.next

    [ pagy.records, cursor_meta(pagy, next_cursor) ]
  end

  private

  def meta(pagy)
    Core::Pagination::Entity.new(
      page: pagy.page,
      per_page: pagy.limit,
      count: pagy.count,
      pages: pagy.pages,
      next_page: pagy.next,
      prev_page: pagy.previous
    )
  end

  def cursor_meta(pagy, next_cursor)
    Core::Pagination::Cursor::Entity.new(
      limit: pagy.limit,
      next_cursor:,
      has_more: next_cursor.present?
    )
  end
end
