require "rails_helper"

RSpec.describe "API::V1::Category::Goals", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let(:user) { create(:user, :verified) }
  let(:headers) { auth_headers_for(user) }
  let(:category) { create(:category, :with_goal, user:, goal_starts_on: Date.new(2026, 8, 1), goal_value: 100) }

  around do |example|
    travel_to(Date.new(2026, 8, 14)) { example.run }
  end

  def category_attributes(payload)
    payload.dig("data", "attributes")
  end

  def category_goals(payload)
    Array(category_attributes(payload)["goals"]).map { |item| item.fetch("attributes") }
  end

  def goal_pairs(payload)
    category_goals(payload).map { |item| [ item["year"], item["month"], item["value"] ] }
  end

  def update_goal(category_id, params, request_headers = headers)
    patch "/api/v1/categories/#{category_id}/goals",
          params: { category_goal: params },
          headers: request_headers,
          as: :json
  end

  describe "PATCH /api/v1/categories/:category_id/goals" do
    context "when authenticated" do
      it "updates the existing goal and creates the next month with the old value" do
        category

        expect {
          update_goal(category.id, { value: 120, starts_on: "2026-08-01" })
        }.to change(Category::Goal::Record, :count).by(1)

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["message"]).to eq("Goal created or updated successfully")
        expect(goal_pairs(response.parsed_body)).to eq(
          [ [ 2026, 8, "120.0" ], [ 2026, 9, "100.0" ] ]
        )
      end

      it "creates a new goal for a different month and restores the old value afterwards" do
        category

        expect {
          update_goal(category.id, { value: 120, starts_on: "2026-10-01" })
        }.to change(Category::Goal::Record, :count).by(2)

        expect(response).to have_http_status(:ok)
        expect(goal_pairs(response.parsed_body)).to eq(
          [ [ 2026, 8, "100.0" ], [ 2026, 10, "120.0" ], [ 2026, 11, "100.0" ] ]
        )
      end

      it "uses only the month and year from starts_on" do
        end_of_month_category = create(:category, :with_goal, user:, goal_starts_on: Date.new(2026, 5, 31), goal_value: 77)
        create(:category_goal, category: end_of_month_category, starts_on: Date.new(2026, 8, 31), value: 78)

        expect {
          update_goal(end_of_month_category.id, { value: 79, starts_on: "2026-09-30" })
        }.to change(Category::Goal::Record, :count).by(2)

        expect(response).to have_http_status(:ok)
        expect(goal_pairs(response.parsed_body)).to eq(
          [
            [ 2026, 5, "77.0" ],
            [ 2026, 8, "78.0" ],
            [ 2026, 9, "79.0" ],
            [ 2026, 10, "78.0" ]
          ]
        )
      end

      it "updates the existing goal without creating another record when change_for_next_months is true" do
        category

        expect {
          update_goal(category.id, { value: 120, starts_on: "2026-08-01", change_for_next_months: true })
        }.not_to change(Category::Goal::Record, :count)

        expect(response).to have_http_status(:ok)
        expect(goal_pairs(response.parsed_body)).to eq(
          [ [ 2026, 8, "120.0" ] ]
        )
      end

      it "starts the first goal when the category has none" do
        category_without_goal = create(:category, user:)

        expect {
          update_goal(category_without_goal.id, { value: 500, starts_on: "2026-08-01" })
        }.to change(Category::Goal::Record, :count).by(1)

        expect(response).to have_http_status(:ok)
        expect(goal_pairs(response.parsed_body)).to eq([ [ 2026, 8, "500.0" ] ])
      end

      it "does not destroy closed-month goals when change_for_next_months is true" do
        create(:category_goal, category:, starts_on: Date.new(2026, 9, 1), value: 86)
        create(:category_goal, category:, starts_on: Date.new(2026, 12, 1), value: 76)
        create(:monthly_status, user:, month: 9, year: 2026)
        create(:monthly_status, :closed, user:, month: 12, year: 2026)

        expect {
          update_goal(category.id, { value: 87, starts_on: "2026-09-01", change_for_next_months: true })
        }.not_to change(Category::Goal::Record, :count)

        expect(response).to have_http_status(:ok)
        expect(goal_pairs(response.parsed_body)).to eq(
          [ [ 2026, 8, "100.0" ], [ 2026, 9, "87.0" ], [ 2026, 12, "76.0" ] ]
        )
      end

      it "rejects a closed month" do
        category
        create(:monthly_status, :closed, user:, month: 8, year: 2026)

        expect {
          update_goal(category.id, { value: 120, starts_on: "2026-08-01" })
        }.not_to change(Category::Goal::Record, :count)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "base")).to eq(
          [ "Goals cannot be changed for this date because the month is already closed" ]
        )
      end

      it "rejects a month before a later closed month" do
        category
        create(:monthly_status, :closed, user:, month: 10, year: 2026)

        expect {
          update_goal(category.id, { value: 120, starts_on: "2026-08-01" })
        }.not_to change(Category::Goal::Record, :count)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "base")).to eq(
          [ "Goals cannot be changed for this date because a later month is already closed" ]
        )
      end

      it "does not restore the previous value when the next month is closed" do
        category
        create(:monthly_status, user:, month: 8, year: 2026)
        create(:monthly_status, :closed, user:, month: 9, year: 2026)

        expect {
          update_goal(category.id, { value: 120, starts_on: "2026-08-01" })
        }.not_to change(Category::Goal::Record, :count)

        expect(response).to have_http_status(:ok)
        expect(goal_pairs(response.parsed_body)).to eq(
          [ [ 2026, 8, "120.0" ] ]
        )
      end

      it "rejects starts_on after goal_ends_on" do
        category.update!(goal_ends_on: Date.new(2026, 9, 1))

        update_goal(category.id, { value: 120, starts_on: "2026-10-01" })

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "starts_on")).to eq(
          [ "must be on or before goal_ends_on" ]
        )
      end

      it "rejects the same value as the current month goal" do
        category

        expect {
          update_goal(category.id, { value: 100, starts_on: "2026-08-01" })
        }.not_to change(Category::Goal::Record, :count)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "value")).to eq(
          [ "must be different from the previous goal" ]
        )
      end

      it "returns 404 for another user's category" do
        update_goal(create(:category, :with_goal).id, { value: 120, starts_on: "2026-08-01" })

        expect(response).to have_http_status(:not_found)
        expect(response.parsed_body["message"]).to eq("Category not found")
      end
    end

    context "when unauthenticated" do
      subject { update_goal(category.id, { value: 120, starts_on: "2026-08-01" }, {}) }

      it_behaves_like "an unauthorized API request"
    end
  end
end
