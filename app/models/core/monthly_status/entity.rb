Core::MonthlyStatus::Entity = Data.define(:id, :user_id, :month, :year, :status) do
  def open? = status == Core::MonthlyStatus::Status::OPEN

  def closed? = status == Core::MonthlyStatus::Status::CLOSED
end
