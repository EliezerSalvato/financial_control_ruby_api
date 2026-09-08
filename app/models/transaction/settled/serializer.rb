class Transaction::Settled::Serializer
  include JSONAPI::Serializer

  set_type :settled_transaction
  attributes :id,
             :transaction_id,
             :category_id,
             :description,
             :kind,
             :status,
             :payment_method,
             :recurrence_type,
             :installments_count,
             :ends_on,
             :canceled_on,
             :occurred_on,
             :settled_on,
             :value,
             :installment_number

  attribute :account_id, if: ->(settled_transaction) { settled_transaction.account_payment? }
  attribute :credit_card_id, if: ->(settled_transaction) { settled_transaction.credit_card_payment? }
  attribute :limit_consumption_type, if: ->(settled_transaction) { settled_transaction.credit_card_payment? }
  attribute :source_account_id, if: ->(settled_transaction) { settled_transaction.transfer_between_accounts? }
  attribute :destination_account_id, if: ->(settled_transaction) { settled_transaction.transfer_between_accounts? }
end
