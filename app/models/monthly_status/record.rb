class MonthlyStatus::Record < ApplicationRecord
  self.table_name = "monthly_statuses"

  has_paper_trail

  belongs_to :user, class_name: "User::Record"
end
