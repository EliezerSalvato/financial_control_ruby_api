require "rails_helper"

RSpec.describe Category::Goal::Record, type: :model do
  it "stores month and year" do
    goal = create(:category_goal, starts_on: Date.new(2026, 8, 11))

    expect(goal.month).to eq(8)
    expect(goal.year).to eq(2026)
  end

  it "enforces uniqueness of category_id, month and year" do
    category = create(:category)
    create(:category_goal, category:, starts_on: Date.new(2026, 8, 1))

    duplicate = Category::Goal::Record.new(
      category:,
      month: 8,
      year: 2026,
      value: 50
    )

    expect { duplicate.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end
end
