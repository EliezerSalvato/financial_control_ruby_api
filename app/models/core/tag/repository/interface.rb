module Core::Tag::Repository::Interface
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
          Solid::Success(:tags_listed, { tags: Array, pagination: Core::Pagination::Entity })
        )
      end
    end

    def find_by_id(user:, id:)
      user => Core::User::Entity
      id => String

      super.tap do
        _1 => (
          Solid::Failure(:tag_not_found, {}) |
          Solid::Success(:tag_found, { tag: Core::Tag::Entity })
        )
      end
    end

    def exists?(user:, name:, excluding_id: nil)
      user => Core::User::Entity
      name => String
      excluding_id => String | NilClass

      super.tap do
        _1 => (true | false)
      end
    end

    def create(user:, attributes:)
      user => Core::User::Entity
      attributes => Hash

      super.tap do
        _1 => (
          Solid::Failure(:tag_creation_failed, { tag: Core::Tag::Entity, errors: Core::Errors }) |
          Solid::Success(:tag_created, { tag: Core::Tag::Entity })
        )
      end
    end

    def update(tag:, attributes:)
      tag => Core::Tag::Entity
      attributes => Hash

      super.tap do
        _1 => (
          Solid::Failure(:tag_update_failed, { tag: Core::Tag::Entity, errors: Core::Errors }) |
          Solid::Success(:tag_updated, { tag: Core::Tag::Entity })
        )
      end
    end

    def destroy(tag:)
      tag => Core::Tag::Entity

      super.tap do
        _1 => (
          Solid::Failure(:tag_destruction_failed, {}) |
          Solid::Success(:tag_destroyed, {})
        )
      end
    end
  end
end
