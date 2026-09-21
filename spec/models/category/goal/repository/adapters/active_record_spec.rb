require "rails_helper"

RSpec.describe Category::Goal::Repository::Adapters::ActiveRecord do
  subject(:repository) { described_class }

  let(:user) { create(:user, :verified) }
  let(:category_record) { create(:category, :with_goal, user:, goal_starts_on: Date.new(2026, 1, 15), goal_value: 500) }
  let(:category) { Category::Mapper.to_entity(category_record) }

  describe "#find_by_starts_on" do
    it "returns Success for the same month and year" do
      result = repository.find_by_starts_on(category:, starts_on: Date.new(2026, 1, 28))

      expect(result).to be_a(Solid::Success)
      expect(result.type).to eq(:goal_found)
      expect(result.value[:goal]).to have_attributes(month: 1, year: 2026, value: 500)
    end

    it "returns Failure when no goal exists in that month" do
      result = repository.find_by_starts_on(category:, starts_on: Date.new(2026, 2, 1))

      expect(result).to be_a(Solid::Failure)
      expect(result.type).to eq(:goal_not_found)
    end
  end

  describe "#find_latest" do
    it "returns the latest goal" do
      create(:category_goal, category: category_record, starts_on: Date.new(2026, 3, 1), value: 700)

      result = repository.find_latest(category:)

      expect(result).to be_a(Solid::Success)
      expect(result.value[:goal]).to have_attributes(month: 3, year: 2026, value: 700)
    end
  end

  describe "#destroy_after" do
    before do
      create(:category_goal, category: category_record, starts_on: Date.new(2026, 3, 1), value: 600)
      create(:category_goal, category: category_record, starts_on: Date.new(2026, 5, 1), value: 700)
    end

    it "destroys later open-month goals" do
      expect {
        result = repository.destroy_after(category:, starts_on: Date.new(2026, 1, 15))

        expect(result).to be_a(Solid::Success)
        expect(result.type).to eq(:goals_destroyed)
      }.to change(Category::Goal::Record, :count).by(-2)

      expect(category_record.goals.reload.map { |goal| [ goal.year, goal.month ] }).to eq([ [ 2026, 1 ] ])
    end

    it "does not destroy goals whose months are closed" do
      create(:monthly_status, :closed, user:, month: 3, year: 2026)

      expect {
        result = repository.destroy_after(category:, starts_on: Date.new(2026, 1, 15))

        expect(result).to be_a(Solid::Success)
      }.to change(Category::Goal::Record, :count).by(-1)

      expect(category_record.goals.reload.map { |goal| [ goal.year, goal.month ] }).to contain_exactly(
        [ 2026, 1 ],
        [ 2026, 3 ]
      )
    end
  end
end
