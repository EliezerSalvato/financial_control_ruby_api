class CreditCard::Serializer
  include JSONAPI::Serializer

  set_type :credit_card
  attributes :id,
             :institution_id,
             :default_payment_account_id,
             :name,
             :total_limit,
             :available_limit,
             :closing_day,
             :due_day,
             :network,
             :active
end
