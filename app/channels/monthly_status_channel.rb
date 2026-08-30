class MonthlyStatusChannel < ApplicationCable::Channel
  def subscribed
    case MonthlyStatus.find(user: current_user, month:, year:)
    in Solid::Success(monthly_status:)
      stream_for MonthlyStatus::Broadcast.stream_target(monthly_status)
      transmit(MonthlyStatus::Broadcast.payload(monthly_status))
    else
      reject
    end
  end

  private

  def month = params[:month]

  def year = params[:year]
end
