module MonthlyStatus::Broadcast
  extend self

  def stream_target(monthly_status)
    [ monthly_status.user_id, monthly_status.year, monthly_status.month ]
  end

  def payload(monthly_status)
    {
      processing: monthly_status.processing,
      last_processed_at: monthly_status.last_processed_at&.iso8601
    }
  end

  def processing_changed(monthly_status)
    MonthlyStatusChannel.broadcast_to(stream_target(monthly_status), payload(monthly_status))
  end
end
