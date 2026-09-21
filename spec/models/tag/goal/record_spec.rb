require "rails_helper"

RSpec.describe Tag::Goal::Record, type: :model do
  it "stores month and year" do
    goal = create(:tag_goal, starts_on: Date.new(2026, 8, 11))

    expect(goal.month).to eq(8)
    expect(goal.year).to eq(2026)
  end

  it "enforces uniqueness of tag_id, month and year" do
    tag = create(:tag)
    create(:tag_goal, tag:, starts_on: Date.new(2026, 8, 1))

    duplicate = Tag::Goal::Record.new(
      tag:,
      month: 8,
      year: 2026,
      value: 50
    )

    expect { duplicate.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end
end
