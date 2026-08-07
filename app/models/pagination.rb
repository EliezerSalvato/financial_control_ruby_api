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
end
