module Core::Transaction::Repository::Interface
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
          Solid::Success(:transactions_listed, { transactions: Array, pagination: Core::Pagination::Entity })
        )
      end
    end

    def find_by_id(user:, id:)
      user => Core::User::Entity
      id => String

      super.tap do
        _1 => (
          Solid::Failure(:transaction_not_found, {}) |
          Solid::Success(:transaction_found, { transaction: Core::Transaction::Entity })
        )
      end
    end

    def create(user:, attributes:)
      user => Core::User::Entity
      attributes => Hash

      super.tap do
        _1 => (
          Solid::Failure(:transaction_creation_failed, { transaction: Core::Transaction::Entity, errors: Core::Errors }) |
          Solid::Success(:transaction_created, { transaction: Core::Transaction::Entity })
        )
      end
    end

    def update(transaction:, attributes:)
      transaction => Core::Transaction::Entity
      attributes => Hash

      super.tap do
        _1 => (
          Solid::Failure(:transaction_update_failed, { transaction: Core::Transaction::Entity, errors: Core::Errors }) |
          Solid::Success(:transaction_updated, { transaction: Core::Transaction::Entity })
        )
      end
    end

    def destroy(transaction:)
      transaction => Core::Transaction::Entity

      super.tap do
        _1 => (
          Solid::Failure(:transaction_destruction_failed, {}) |
          Solid::Success(:transaction_destroyed, {})
        )
      end
    end
  end
end
