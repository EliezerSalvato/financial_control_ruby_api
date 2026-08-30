Core::MonthlyStatus::Entity = Data.define(:id, :user_id, :month, :year, :status, :processing, :last_processed_at) do
  def open? = status == Core::MonthlyStatus::Status::OPEN

  def closed? = status == Core::MonthlyStatus::Status::CLOSED
end
