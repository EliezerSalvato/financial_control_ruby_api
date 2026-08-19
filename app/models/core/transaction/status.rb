module Core::Transaction::Status
  PENDING = "pending"
  ACTIVE = "active"
  COMPLETED = "completed"
  CANCELED = "canceled"

  ALL = [ PENDING, ACTIVE, COMPLETED, CANCELED ].freeze
end
