class AddProcessingToMonthlyStatuses < ActiveRecord::Migration[8.1]
  def change
    add_column :monthly_statuses, :processing, :boolean, null: false, default: false
    add_column :monthly_statuses, :last_processed_at, :datetime
  end
end
