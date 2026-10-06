class TransactionImportChannel < ApplicationCable::Channel
  def subscribed
    stream_for Transaction::Import::Broadcast.stream_target(current_user.id)
  end
end
