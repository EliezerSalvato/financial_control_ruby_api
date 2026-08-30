class MonthlyStatus::Record < ApplicationRecord
  self.table_name = "monthly_statuses"

  has_paper_trail

  belongs_to :user, class_name: "User::Record"

  after_update_commit :broadcast_processing_change, if: :saved_change_to_processing?

  private

  def broadcast_processing_change
    MonthlyStatus::Broadcast.processing_changed(MonthlyStatus::Mapper.to_entity(self))
  end
end
