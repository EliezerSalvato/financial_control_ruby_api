class CreateMonthlyStatuses < ActiveRecord::Migration[8.1]
  def change
    create_enum :monthly_status, %w[open closed]

    create_table :monthly_statuses, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid, index: true
      t.integer :month, null: false
      t.integer :year, null: false
      t.enum :status, enum_type: :monthly_status, null: false, default: "open"

      t.timestamps
    end

    add_index :monthly_statuses, %i[user_id month year], unique: true
    add_index :monthly_statuses, %i[status year month]

    add_check_constraint :monthly_statuses, "month BETWEEN 1 AND 12", name: "monthly_statuses_month_range"
    add_check_constraint :monthly_statuses, "year BETWEEN 1 AND 9999", name: "monthly_statuses_year_range"
  end
end
