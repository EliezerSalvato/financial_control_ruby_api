require "rails_helper"

RSpec.describe "API::V1::Goals targets", type: :request do
  let(:user) { create(:user, :verified) }
  let(:headers) { auth_headers_for(user) }

  def list_goal_targets(query = {}, request_headers = headers)
    get "/api/v1/goals/targets", params: query, headers: request_headers
  end

  def item_attributes(payload = response.parsed_body)
    payload.fetch("data").map { |item| item.fetch("attributes") }
  end

  describe "GET /api/v1/goals/targets" do
    context "when authenticated" do
      it "returns categories and tags with the goal applicable to the month" do
        housing = create(:category, user:, name: "Moradia", color: "#EF4444")
        create(:category_goal, category: housing, starts_on: Date.new(2026, 1, 1), value: 1500)
        create(:category_goal, category: housing, starts_on: Date.new(2026, 9, 1), value: 2000)
        create(:category, user:, name: "Sem meta")

        casa = create(:tag, user:, name: "Casa", color: "#10B981")
        create(:tag_goal, tag: casa, starts_on: Date.new(2026, 8, 1), value: 1000)
        create(:tag, user:, name: "Sem meta")

        other_user = create(:user, :verified)
        other_category = create(:category, user: other_user, name: "Outra")
        create(:category_goal, category: other_category, starts_on: Date.new(2026, 9, 1), value: 50)

        list_goal_targets(month: 9, year: 2026)

        by_id = item_attributes.index_by { |item| item.fetch("id") }

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["type"]).to eq("collection")
        expect(response.parsed_body.dig("data", 0, "type")).to eq("goal_target")
        expect(by_id.keys).to contain_exactly(housing.id, casa.id)
        expect(item_attributes.map { |item| item.fetch("name") }).to eq(%w[Moradia Casa])
        expect(by_id.fetch(housing.id)).to include(
          "id" => housing.id,
          "kind" => "category",
          "name" => "Moradia",
          "color" => "#EF4444",
          "value" => "2000.0"
        )
        expect(by_id.fetch(casa.id)).to include(
          "id" => casa.id,
          "kind" => "tag",
          "name" => "Casa",
          "color" => "#10B981",
          "value" => "1000.0"
        )
      end

      it "uses the latest goal that starts on or before the requested month" do
        housing = create(:category, user:, name: "Moradia")
        create(:category_goal, category: housing, starts_on: Date.new(2026, 1, 1), value: 80)
        create(:category_goal, category: housing, starts_on: Date.new(2026, 9, 1), value: 90)
        create(:category_goal, category: housing, starts_on: Date.new(2026, 10, 1), value: 100)

        list_goal_targets(month: 9, year: 2026)

        expect(item_attributes).to contain_exactly(
          include("id" => housing.id, "kind" => "category", "value" => "90.0")
        )
      end

      it "carries a previous goal forward when the month has no row of its own" do
        casa = create(:tag, user:, name: "Casa")
        create(:tag_goal, tag: casa, starts_on: Date.new(2026, 1, 1), value: 400)

        list_goal_targets(month: 9, year: 2026)

        expect(item_attributes).to contain_exactly(
          include("id" => casa.id, "kind" => "tag", "value" => "400.0")
        )
      end

      it "omits categories and tags whose first goal starts after the requested month" do
        create(:category, :with_goal, user:, name: "Futuro", goal_starts_on: Date.new(2026, 10, 1), goal_value: 300)
        create(:tag, :with_goal, user:, name: "Depois", goal_starts_on: Date.new(2026, 11, 1), goal_value: 50)

        list_goal_targets(month: 9, year: 2026)

        expect(item_attributes).to eq([])
      end

      it "omits categories and tags after goal_ends_on" do
        housing = create(:category, :with_goal, user:, name: "Moradia", goal_starts_on: Date.new(2026, 1, 1), goal_value: 500)
        housing.update!(goal_ends_on: Date.new(2026, 8, 1))
        casa = create(:tag, :with_goal, user:, name: "Casa", goal_starts_on: Date.new(2026, 1, 1), goal_value: 200)
        casa.update!(goal_ends_on: Date.new(2026, 9, 1))

        list_goal_targets(month: 9, year: 2026)

        expect(item_attributes).to contain_exactly(
          include("id" => casa.id, "kind" => "tag", "value" => "200.0")
        )
      end

      it "returns an empty collection when there are no matching goals" do
        list_goal_targets(month: 9, year: 2026)

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["data"]).to eq([])
      end

      it "returns 422 when month is missing" do
        list_goal_targets(year: 2026)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "month")).to be_present
      end

      it "returns 422 when year is missing" do
        list_goal_targets(month: 9)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "year")).to be_present
      end

      it "returns 422 for an invalid month" do
        list_goal_targets(month: 13, year: 2026)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "month")).to be_present
      end

      it "returns 422 for month 0" do
        list_goal_targets(month: 0, year: 2026)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "month")).to be_present
      end

      it "returns 422 for year 0" do
        list_goal_targets(month: 9, year: 0)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "year")).to be_present
      end

      it "returns 422 for a year above 9999" do
        list_goal_targets(month: 9, year: 10_000)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "year")).to be_present
      end
    end

    context "when unauthenticated" do
      subject { list_goal_targets({ month: 9, year: 2026 }, {}) }

      it_behaves_like "an unauthorized API request"
    end
  end
end
