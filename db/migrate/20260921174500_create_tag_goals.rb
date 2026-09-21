class CreateTagGoals < ActiveRecord::Migration[8.1]
  def change
    add_column :tags, :goal_ends_on, :date

    create_table :tag_goals, id: :uuid do |t|
      t.references :tag, null: false, foreign_key: true, type: :uuid, index: false
      t.integer :month, null: false
      t.integer :year, null: false
      t.decimal :value, precision: 15, scale: 2, null: false

      t.timestamps
    end

    add_index :tag_goals, %i[tag_id month year], unique: true

    add_check_constraint :tag_goals, "value >= 0", name: "tag_goals_value_non_negative"
    add_check_constraint :tag_goals, "month >= 1 AND month <= 12", name: "tag_goals_month_range"
    add_check_constraint :tag_goals, "year >= 1 AND year <= 9999", name: "tag_goals_year_range"
  end
end
