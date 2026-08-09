module Core::Institution::Repository::Interface
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
          Solid::Success(:institutions_listed, { institutions: Array, pagination: Core::Pagination::Entity })
        )
      end
    end

    def find_by_id(user:, id:)
      user => Core::User::Entity
      id => String

      super.tap do
        _1 => (
          Solid::Failure(:institution_not_found, {}) |
          Solid::Success(:institution_found, { institution: Core::Institution::Entity })
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
          Solid::Failure(:institution_creation_failed, { institution: Core::Institution::Entity, errors: Core::Errors }) |
          Solid::Success(:institution_created, { institution: Core::Institution::Entity })
        )
      end
    end

    def update(institution:, attributes:)
      institution => Core::Institution::Entity
      attributes => Hash

      super.tap do
        _1 => (
          Solid::Failure(:institution_update_failed, { institution: Core::Institution::Entity, errors: Core::Errors }) |
          Solid::Success(:institution_updated, { institution: Core::Institution::Entity })
        )
      end
    end

    def destroy(institution:)
      institution => Core::Institution::Entity

      super.tap do
        _1 => (
          Solid::Failure(:institution_destruction_failed, {}) |
          Solid::Success(:institution_destroyed, {})
        )
      end
    end
  end
end
