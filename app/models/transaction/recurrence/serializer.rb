class Transaction::Recurrence::Serializer
  include JSONAPI::Serializer

  set_type :transaction_recurrence
  attributes :id, :starts_on, :value
end
