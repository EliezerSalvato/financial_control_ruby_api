class CreateCategoryGoals < ActiveRecord::Migration[8.1]
  def change
    add_column :categories, :goal_ends_on, :date

    create_table :category_goals, id: :uuid do |t|
      t.references :category, null: false, foreign_key: true, type: :uuid, index: false
      t.integer :month, null: false
      t.integer :year, null: false
      t.decimal :value, precision: 15, scale: 2, null: false

      t.timestamps
    end

    add_index :category_goals, %i[category_id month year], unique: true

    add_check_constraint :category_goals, "value >= 0", name: "category_goals_value_non_negative"
    add_check_constraint :category_goals, "month >= 1 AND month <= 12", name: "category_goals_month_range"
    add_check_constraint :category_goals, "year >= 1 AND year <= 9999", name: "category_goals_year_range"
  end
end
