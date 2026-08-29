module Core::Transaction::Settlement::Repository::Interface
  include Solid::Adapters::Interface

  module Methods
    def create(
      transaction_id:, occurred_on:, settled_on:, value:, installment_number:, account_id: nil, source_account_id: nil, destination_account_id: nil, limit_consumed: nil
    )
      transaction_id => String
      occurred_on => Date
      settled_on => Date
      value => Numeric
      installment_number => Integer | NilClass
      account_id => String | NilClass
      source_account_id => String | NilClass
      destination_account_id => String | NilClass
      limit_consumed => Numeric | NilClass

      super.tap do
        _1 => (
          Solid::Success(:transaction_settlement_created, { settlement: Core::Transaction::Settlement::Entity }) |
          Solid::Success(:already_settled, { settlement: Core::Transaction::Settlement::Entity }) |
          Solid::Failure(:transaction_settlement_creation_failed, { errors: Core::Errors })
        )
      end
    end

    def settled_keys(transaction_ids:, occurred_on_range:)
      transaction_ids => Array
      occurred_on_range => Range

      super.tap do
        _1 => Solid::Success(:transaction_settlements_listed, { keys: Array })
      end
    end

    def count_for(transaction_id:)
      transaction_id => String

      super.tap do
        _1 => Solid::Success(:transaction_settlements_counted, { count: Integer })
      end
    end
  end
end
