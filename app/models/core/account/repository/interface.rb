module Core::Account::Repository::Interface
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
          Solid::Success(:accounts_listed, { accounts: Array, pagination: Core::Pagination::Entity })
        )
      end
    end

    def find_by_id(user:, id:)
      user => Core::User::Entity
      id => String

      super.tap do
        _1 => (
          Solid::Failure(:account_not_found, {}) |
          Solid::Success(:account_found, { account: Core::Account::Entity })
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
          Solid::Failure(:account_creation_failed, { account: Core::Account::Entity, errors: Core::Errors }) |
          Solid::Success(:account_created, { account: Core::Account::Entity })
        )
      end
    end

    def update(account:, attributes:)
      account => Core::Account::Entity
      attributes => Hash

      super.tap do
        _1 => (
          Solid::Failure(:account_update_failed, { account: Core::Account::Entity, errors: Core::Errors }) |
          Solid::Success(:account_updated, { account: Core::Account::Entity })
        )
      end
    end

    def destroy(account:)
      account => Core::Account::Entity

      super.tap do
        _1 => (
          Solid::Failure(:account_destruction_failed, {}) |
          Solid::Success(:account_destroyed, {})
        )
      end
    end
  end
end
