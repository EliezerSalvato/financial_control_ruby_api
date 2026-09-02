module Core::Pagination::Interface
  include Solid::Adapters::Interface

  module Methods
    def paginate(collection, page:, per_page:)
      page => Integer
      per_page => Integer

      super.tap { _1 => [ Object, Core::Pagination::Entity ] }
    end

    def paginate_by_cursor(collection, after:, limit:)
      limit => Integer

      super.tap { _1 => [ Object, Core::Pagination::Cursor::Entity ] }
    end
  end
end
