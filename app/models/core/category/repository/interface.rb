module Core::Category::Repository::Interface
  include Solid::Adapters::Interface

  module Methods
    def list(user:, filters:, sorting:, page:, per_page:)
      user => Core::User::Entity
      filters => Hash
      sorting => String
      page => Integer
      per_page => Integer

      super.tap do
        _1 => (
          Solid::Failure(:invalid_filters, {}) |
          Solid::Success(:categories_listed, { categories: Array, pagination: Core::Pagination::Entity })
        )
      end
    end

    def find_by_id(user:, id:)
      user => Core::User::Entity
      UUID.valid?(id) => true

      super.tap do
        _1 => (
          Solid::Failure(:category_not_found, {}) |
          Solid::Success(:category_found, { category: Core::Category::Entity })
        )
      end
    end

    def exists?(user:, name:, excluding_id: nil)
      user => Core::User::Entity
      name => String
      excluding_id.nil? || UUID.valid?(excluding_id) => true

      super.tap do
        _1 => (true | false)
      end
    end

    def create(user:, attributes:)
      user => Core::User::Entity
      attributes => Hash

      super.tap do
        _1 => (
          Solid::Failure(:category_creation_failed, { category: Core::Category::Entity, errors: Core::Errors }) |
          Solid::Success(:category_created, { category: Core::Category::Entity })
        )
      end
    end

    def update(category:, attributes:)
      category => Core::Category::Entity
      attributes => Hash

      super.tap do
        _1 => (
          Solid::Failure(:category_update_failed, { category: Core::Category::Entity, errors: Core::Errors }) |
          Solid::Success(:category_updated, { category: Core::Category::Entity })
        )
      end
    end

    def destroy(category:)
      category => Core::Category::Entity

      super.tap do
        _1 => (
          Solid::Failure(:category_destruction_failed, {}) |
          Solid::Success(:category_destroyed, {})
        )
      end
    end
  end
end
