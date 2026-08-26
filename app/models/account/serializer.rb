class Account::Serializer
  include JSONAPI::Serializer

  set_type :account
  attributes :id,
             :name,
             :kind,
             :current_balance,
             :color,
             :allow_negative_balance,
             :active

  attribute :institution_id, if: ->(account) { account.bank_account? }
  attribute :bank_account_type, if: ->(account) { account.bank_account? }
end
