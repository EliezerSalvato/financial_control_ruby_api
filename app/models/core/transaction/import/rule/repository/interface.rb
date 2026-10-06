module Core::Transaction::Import::Rule::Repository::Interface
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
          Solid::Success(:import_rules_listed, { import_rules: Array, pagination: Core::Pagination::Entity })
        )
      end
    end

    def list_active(user:)
      user => Core::User::Entity

      super.tap do
        _1 => Solid::Success(:import_rules_found, { import_rules: Array })
      end
    end

    def find_by_id(user:, id:)
      user => Core::User::Entity
      UUID.valid?(id) => true

      super.tap do
        _1 => (
          Solid::Failure(:import_rule_not_found, {}) |
          Solid::Success(:import_rule_found, { import_rule: Core::Transaction::Import::Rule::Entity })
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
          Solid::Failure(:import_rule_creation_failed, { import_rule: Core::Transaction::Import::Rule::Entity, errors: Core::Errors }) |
          Solid::Success(:import_rule_created, { import_rule: Core::Transaction::Import::Rule::Entity })
        )
      end
    end

    def update(import_rule:, attributes:)
      import_rule => Core::Transaction::Import::Rule::Entity
      attributes => Hash

      super.tap do
        _1 => (
          Solid::Failure(:import_rule_update_failed, { import_rule: Core::Transaction::Import::Rule::Entity, errors: Core::Errors }) |
          Solid::Success(:import_rule_updated, { import_rule: Core::Transaction::Import::Rule::Entity })
        )
      end
    end

    def destroy(import_rule:)
      import_rule => Core::Transaction::Import::Rule::Entity

      super.tap do
        _1 => (
          Solid::Failure(:import_rule_destruction_failed, {}) |
          Solid::Success(:import_rule_destroyed, {})
        )
      end
    end
  end
end
