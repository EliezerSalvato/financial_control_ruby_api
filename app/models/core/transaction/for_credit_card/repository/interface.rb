module Core::Transaction::ForCreditCard::Repository::Interface
  include Solid::Adapters::Interface

  module Methods
    def create(transaction:, credit_card_id:, limit_consumption_type:)
      transaction => Core::Transaction::Entity
      credit_card_id => String
      limit_consumption_type => String | NilClass

      super.tap do
        _1 => (
          Solid::Failure(:for_credit_card_creation_failed, { errors: Core::Errors }) |
          Solid::Success(:for_credit_card_created, {})
        )
      end
    end

    def upsert(transaction:, credit_card_id:, limit_consumption_type:)
      transaction => Core::Transaction::Entity
      credit_card_id => String | NilClass
      limit_consumption_type => String | NilClass

      super.tap do
        _1 => (
          Solid::Failure(:for_credit_card_upsert_failed, { errors: Core::Errors }) |
          Solid::Success(:for_credit_card_upserted, {})
        )
      end
    end

    def destroy(transaction:)
      transaction => Core::Transaction::Entity

      super.tap do
        _1 => (
          Solid::Failure(:for_credit_card_destruction_failed, { errors: Core::Errors }) |
          Solid::Success(:for_credit_card_destroyed, {})
        )
      end
    end
  end
end
