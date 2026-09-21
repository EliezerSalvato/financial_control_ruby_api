require "rails_helper"

RSpec.describe Core::Tag::Entity do
  include ActiveSupport::Testing::TimeHelpers

  def build_tag(goal_ends_on: nil, goals: [])
    described_class.new(
      id: UUID.generate,
      user_id: UUID.generate,
      name: "Food",
      color: "#3B82F6",
      active: true,
      goal_ends_on:,
      goals:
    )
  end

  def build_goal(starts_on:, value:)
    Core::Tag::Goal::Entity.new(id: UUID.generate, month: starts_on.month, year: starts_on.year, value:)
  end

  it "returns nil current_goal when there are no goals" do
    expect(build_tag.current_goal).to be_nil
  end

  it "returns nil current_goal after goal_ends_on" do
    tag = build_tag(
      goal_ends_on: Date.new(2026, 6, 30),
      goals: [ build_goal(starts_on: Date.new(2026, 1, 15), value: 500) ]
    )

    travel_to(Date.new(2026, 7, 1)) do
      expect(tag.current_goal).to be_nil
    end
  end

  it "falls back to the earliest goal when every goal starts in a future month" do
    earliest = build_goal(starts_on: Date.new(2026, 10, 1), value: 400)
    later = build_goal(starts_on: Date.new(2026, 12, 1), value: 500)
    tag = build_tag(goals: [ later, earliest ])

    travel_to(Date.new(2026, 8, 1)) do
      expect(tag.current_goal).to eq(earliest)
    end
  end
end
