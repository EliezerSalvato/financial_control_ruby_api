class MonthlyStatement::Serializer
  include JSONAPI::Serializer

  set_type :monthly_statement
  attributes :id,
             :kind,
             :description,
             :recurrence_type,
             :payment_method,
             :resource_id,
             :resource_name,
             :resource_brand,
             :opening_date,
             :closing_date,
             :due_date,
             :value,
             :first_recurrence_on,
             :current_recurrence_on,
             :starts_on,
             :ends_on,
             :canceled_on
end
