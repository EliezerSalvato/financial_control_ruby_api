class MonthlyStatement::Transfer::Serializer
  include JSONAPI::Serializer

  set_type :monthly_statement_transfer
  attributes :id,
             :kind,
             :description,
             :recurrence_type,
             :source_account_id,
             :source_account_name,
             :source_account_brand,
             :destination_account_id,
             :destination_account_name,
             :destination_account_brand,
             :opening_date,
             :closing_date,
             :value,
             :first_recurrence_on,
             :current_recurrence_on,
             :starts_on,
             :ends_on,
             :canceled_on
end
