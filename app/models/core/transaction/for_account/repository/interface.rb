module Core::Transaction::ForAccount::Repository::Interface
  include Solid::Adapters::Interface

  module Methods
    def create(transaction:, account_id:)
      transaction => Core::Transaction::Entity
      account_id => String

      super.tap do
        _1 => (
          Solid::Failure(:for_account_creation_failed, { errors: Core::Errors }) |
          Solid::Success(:for_account_created, {})
        )
      end
    end

    def upsert(transaction:, account_id:)
      transaction => Core::Transaction::Entity
      account_id => String | NilClass

      super.tap do
        _1 => (
          Solid::Failure(:for_account_upsert_failed, { errors: Core::Errors }) |
          Solid::Success(:for_account_upserted, {})
        )
      end
    end

    def destroy(transaction:)
      transaction => Core::Transaction::Entity

      super.tap do
        _1 => (
          Solid::Failure(:for_account_destruction_failed, { errors: Core::Errors }) |
          Solid::Success(:for_account_destroyed, {})
        )
      end
    end
  end
end
