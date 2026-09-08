module Core::Transaction::ForTransferBetweenAccounts::Repository::Interface
  include Solid::Adapters::Interface

  module Methods
    def create(transaction:, source_account_id:, destination_account_id:)
      transaction => Core::Transaction::Entity
      UUID.valid?(source_account_id) => true
      UUID.valid?(destination_account_id) => true

      super.tap do
        _1 => (
          Solid::Failure(:for_transfer_between_accounts_creation_failed, { errors: Core::Errors }) |
          Solid::Success(:for_transfer_between_accounts_created, {})
        )
      end
    end

    def upsert(transaction:, source_account_id:, destination_account_id:)
      transaction => Core::Transaction::Entity
      source_account_id.nil? || UUID.valid?(source_account_id) => true
      destination_account_id.nil? || UUID.valid?(destination_account_id) => true

      super.tap do
        _1 => (
          Solid::Failure(:for_transfer_between_accounts_upsert_failed, { errors: Core::Errors }) |
          Solid::Success(:for_transfer_between_accounts_upserted, {})
        )
      end
    end

    def destroy(transaction:)
      transaction => Core::Transaction::Entity

      super.tap do
        _1 => (
          Solid::Failure(:for_transfer_between_accounts_destruction_failed, { errors: Core::Errors }) |
          Solid::Success(:for_transfer_between_accounts_destroyed, {})
        )
      end
    end
  end
end
