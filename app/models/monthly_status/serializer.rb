class MonthlyStatus::Serializer
  include JSONAPI::Serializer

  set_type :monthly_status
  attributes :id, :month, :year, :status, :processing, :last_processed_at
end
