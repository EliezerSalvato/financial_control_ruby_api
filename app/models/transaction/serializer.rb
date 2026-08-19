class Transaction::Serializer
  include JSONAPI::Serializer

  set_type :transaction
  attributes :id,
             :category_id,
             :description,
             :kind,
             :status,
             :payment_method,
             :recurrence_type,
             :installments_count,
             :ends_on,
             :tag_ids,
             :current_value

  attribute :account_id, if: ->(transaction) { transaction.account_payment? }
  attribute :credit_card_id, if: ->(transaction) { transaction.credit_card_payment? }
  attribute :limit_consumption_type, if: ->(transaction) { transaction.credit_card_payment? }
  attribute :source_account_id, if: ->(transaction) { transaction.transfer_between_accounts? }
  attribute :destination_account_id, if: ->(transaction) { transaction.transfer_between_accounts? }

  attribute :recurrences do |transaction|
    Transaction::Recurrence::Serializer.new(transaction.recurrences).serializable_hash.fetch(:data)
  end
end
