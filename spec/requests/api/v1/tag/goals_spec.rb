require "rails_helper"

RSpec.describe "API::V1::Tag::Goals", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let(:user) { create(:user, :verified) }
  let(:headers) { auth_headers_for(user) }
  let(:tag) { create(:tag, :with_goal, user:, goal_starts_on: Date.new(2026, 8, 1), goal_value: 100) }

  around do |example|
    travel_to(Date.new(2026, 8, 14)) { example.run }
  end

  def tag_attributes(payload)
    payload.dig("data", "attributes")
  end

  def tag_goals(payload)
    Array(tag_attributes(payload)["goals"]).map { |item| item.fetch("attributes") }
  end

  def goal_pairs(payload)
    tag_goals(payload).map { |item| [ item["year"], item["month"], item["value"] ] }
  end

  def update_goal(tag_id, params, request_headers = headers)
    patch "/api/v1/tags/#{tag_id}/goals",
          params: { tag_goal: params },
          headers: request_headers,
          as: :json
  end

  describe "PATCH /api/v1/tags/:tag_id/goals" do
    context "when authenticated" do
      context "when changing only the current month" do
        it "updates the existing goal and creates the next month with the old value" do
          tag

          expect {
            update_goal(tag.id, { value: 120, starts_on: "2026-08-01" })
          }.to change(Tag::Goal::Record, :count).by(1)

          expect(response).to have_http_status(:ok)
          expect(response.parsed_body["message"]).to eq("Goal created or updated successfully")
          expect(goal_pairs(response.parsed_body)).to eq(
            [ [ 2026, 8, "120.0" ], [ 2026, 9, "100.0" ] ]
          )
        end

        it "creates a new goal for a different month and restores the old value afterwards" do
          tag

          expect {
            update_goal(tag.id, { value: 120, starts_on: "2026-10-01" })
          }.to change(Tag::Goal::Record, :count).by(2)

          expect(response).to have_http_status(:ok)
          expect(goal_pairs(response.parsed_body)).to eq(
            [ [ 2026, 8, "100.0" ], [ 2026, 10, "120.0" ], [ 2026, 11, "100.0" ] ]
          )
        end

        it "uses only the month and year from starts_on" do
          end_of_month_tag = create(:tag, :with_goal, user:, goal_starts_on: Date.new(2026, 5, 31), goal_value: 77)
          create(:tag_goal, tag: end_of_month_tag, starts_on: Date.new(2026, 8, 31), value: 78)

          expect {
            update_goal(end_of_month_tag.id, { value: 79, starts_on: "2026-09-30" })
          }.to change(Tag::Goal::Record, :count).by(2)

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

        it "updates the existing goal when starts_on is a different day in the same month" do
          tag

          expect {
            update_goal(tag.id, { value: 120, starts_on: "2026-08-15" })
          }.to change(Tag::Goal::Record, :count).by(1)

          expect(response).to have_http_status(:ok)
          expect(goal_pairs(response.parsed_body)).to eq(
            [ [ 2026, 8, "120.0" ], [ 2026, 9, "100.0" ] ]
          )
        end

        it "does not create a next-month goal when one already exists" do
          create(:tag_goal, tag:, starts_on: Date.new(2026, 9, 1), value: 150)

          expect {
            update_goal(tag.id, { value: 120, starts_on: "2026-08-01" })
          }.not_to change(Tag::Goal::Record, :count)

          expect(response).to have_http_status(:ok)
          expect(goal_pairs(response.parsed_body)).to eq(
            [ [ 2026, 8, "120.0" ], [ 2026, 9, "150.0" ] ]
          )
        end

        it "does not create a next-month goal past goal_ends_on" do
          tag.update!(goal_ends_on: Date.new(2026, 8, 31))

          expect {
            update_goal(tag.id, { value: 120, starts_on: "2026-08-01" })
          }.not_to change(Tag::Goal::Record, :count)

          expect(response).to have_http_status(:ok)
          expect(goal_pairs(response.parsed_body)).to eq(
            [ [ 2026, 8, "120.0" ] ]
          )
        end
      end

      context "when changing the current and following months" do
        it "updates the existing goal without creating another record" do
          tag

          expect {
            update_goal(tag.id, { value: 120, starts_on: "2026-08-01", change_for_next_months: true })
          }.not_to change(Tag::Goal::Record, :count)

          expect(response).to have_http_status(:ok)
          expect(goal_pairs(response.parsed_body)).to eq(
            [ [ 2026, 8, "120.0" ] ]
          )
        end

        it "creates a new goal for a different month and removes later goals" do
          tag

          expect {
            update_goal(tag.id, { value: 120, starts_on: "2026-10-01", change_for_next_months: true })
          }.to change(Tag::Goal::Record, :count).by(1)

          expect(response).to have_http_status(:ok)
          expect(goal_pairs(response.parsed_body)).to eq(
            [ [ 2026, 8, "100.0" ], [ 2026, 10, "120.0" ] ]
          )
        end
      end

      context "with an existing goal timeline" do
        let(:tag) { create(:tag, :with_goal, user:, goal_starts_on: Date.new(2026, 1, 1), goal_value: 66) }

        before do
          create(:tag_goal, tag:, starts_on: Date.new(2026, 8, 1), value: 76)
          create(:tag_goal, tag:, starts_on: Date.new(2026, 9, 1), value: 86)
          create(:tag_goal, tag:, starts_on: Date.new(2026, 12, 1), value: 76)
        end

        it "updates the month and removes every later goal when change_for_next_months is true" do
          expect {
            update_goal(tag.id, { value: 87, starts_on: "2026-09-01", change_for_next_months: true })
          }.to change(Tag::Goal::Record, :count).by(-1)

          expect(response).to have_http_status(:ok)
          expect(goal_pairs(response.parsed_body)).to eq(
            [ [ 2026, 1, "66.0" ], [ 2026, 8, "76.0" ], [ 2026, 9, "87.0" ] ]
          )
        end

        it "updates the month, creates the next month with the previous value, and keeps later goals" do
          expect {
            update_goal(tag.id, { value: 87, starts_on: "2026-09-01" })
          }.to change(Tag::Goal::Record, :count).by(1)

          expect(response).to have_http_status(:ok)
          expect(goal_pairs(response.parsed_body)).to eq(
            [
              [ 2026, 1, "66.0" ],
              [ 2026, 8, "76.0" ],
              [ 2026, 9, "87.0" ],
              [ 2026, 10, "86.0" ],
              [ 2026, 12, "76.0" ]
            ]
          )
        end

        it "does not destroy closed-month goals when change_for_next_months is true" do
          create(:monthly_status, user:, month: 9, year: 2026)
          create(:monthly_status, :closed, user:, month: 12, year: 2026)

          expect {
            update_goal(tag.id, { value: 87, starts_on: "2026-09-01", change_for_next_months: true })
          }.not_to change(Tag::Goal::Record, :count)

          expect(response).to have_http_status(:ok)
          expect(goal_pairs(response.parsed_body)).to eq(
            [ [ 2026, 1, "66.0" ], [ 2026, 8, "76.0" ], [ 2026, 9, "87.0" ], [ 2026, 12, "76.0" ] ]
          )
        end
      end

      it "starts the first goal when the tag has none" do
        tag_without_goal = create(:tag, user:)

        expect {
          update_goal(tag_without_goal.id, { value: 500, starts_on: "2026-08-01" })
        }.to change(Tag::Goal::Record, :count).by(1)

        expect(response).to have_http_status(:ok)
        expect(goal_pairs(response.parsed_body)).to eq([ [ 2026, 8, "500.0" ] ])
      end

      it "rejects a closed month" do
        tag
        create(:monthly_status, :closed, user:, month: 8, year: 2026)

        expect {
          update_goal(tag.id, { value: 120, starts_on: "2026-08-01" })
        }.not_to change(Tag::Goal::Record, :count)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "base")).to eq(
          [ "Goals cannot be changed for this date because the month is already closed" ]
        )
      end

      it "rejects a month before a later closed month" do
        tag
        create(:monthly_status, :closed, user:, month: 10, year: 2026)

        expect {
          update_goal(tag.id, { value: 120, starts_on: "2026-08-01" })
        }.not_to change(Tag::Goal::Record, :count)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "base")).to eq(
          [ "Goals cannot be changed for this date because a later month is already closed" ]
        )
      end

      it "does not restore the previous value when the next month is closed" do
        tag
        create(:monthly_status, user:, month: 8, year: 2026)
        create(:monthly_status, :closed, user:, month: 9, year: 2026)

        expect {
          update_goal(tag.id, { value: 120, starts_on: "2026-08-01" })
        }.not_to change(Tag::Goal::Record, :count)

        expect(response).to have_http_status(:ok)
        expect(goal_pairs(response.parsed_body)).to eq(
          [ [ 2026, 8, "120.0" ] ]
        )
      end

      it "rejects starts_on after goal_ends_on" do
        tag.update!(goal_ends_on: Date.new(2026, 9, 1))

        update_goal(tag.id, { value: 120, starts_on: "2026-10-01" })

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "starts_on")).to eq(
          [ "must be on or before goal_ends_on" ]
        )
      end

      it "rejects a missing value" do
        update_goal(tag.id, { starts_on: "2026-08-01" })

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "value")).to be_present
      end

      it "rejects the same value as the current month goal" do
        tag

        expect {
          update_goal(tag.id, { value: 100, starts_on: "2026-08-01" })
        }.not_to change(Tag::Goal::Record, :count)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "value")).to eq(
          [ "must be different from the previous goal" ]
        )
      end

      it "returns 404 for another user's tag" do
        update_goal(create(:tag, :with_goal).id, { value: 120, starts_on: "2026-08-01" })

        expect(response).to have_http_status(:not_found)
        expect(response.parsed_body["message"]).to eq("Tag not found")
      end
    end

    context "when unauthenticated" do
      subject { update_goal(tag.id, { value: 120, starts_on: "2026-08-01" }, {}) }

      it_behaves_like "an unauthorized API request"
    end
  end
end
