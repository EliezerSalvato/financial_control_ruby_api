require "rails_helper"

RSpec.describe "API::V1::MonthlyStatuses", type: :request do
  let(:user) { create(:user, :verified) }
  let(:headers) { auth_headers_for(user) }

  def monthly_status_attributes(payload = response.parsed_body)
    payload.dig("data", "attributes")
  end

  describe "GET /api/v1/monthly_statuses" do
    def show_monthly_status(query = {}, request_headers = headers)
      get "/api/v1/monthly_statuses", params: query, headers: request_headers
    end

    context "when authenticated" do
      it "returns the persisted status for an existing month" do
        monthly_status = create(:monthly_status, :closed, user:, month: 8, year: 2026)

        show_monthly_status(month: 8, year: 2026)

        expect(response).to have_http_status(:ok)
        expect(monthly_status_attributes).to include(
          "id" => monthly_status.id,
          "month" => 8,
          "year" => 2026,
          "status" => "closed"
        )
      end

      it "returns 404 when the month is missing" do
        expect {
          show_monthly_status(month: 8, year: 2026)
        }.not_to change(MonthlyStatus::Record, :count)

        expect(response).to have_http_status(:not_found)
        expect(response.parsed_body["message"]).to eq("Monthly status not found")
      end

      it "does not leak another user's closed month" do
        other_user = create(:user, :verified)
        create(:monthly_status, :closed, user: other_user, month: 8, year: 2026)

        expect {
          show_monthly_status(month: 8, year: 2026)
        }.not_to change(MonthlyStatus::Record, :count)

        expect(response).to have_http_status(:not_found)
        expect(response.parsed_body["message"]).to eq("Monthly status not found")
        expect(MonthlyStatus::Record.find_by!(user_id: other_user.id, month: 8, year: 2026).status).to eq("closed")
        expect(MonthlyStatus::Record.find_by(user_id: user.id, month: 8, year: 2026)).to be_nil
      end

      it "returns 422 for an invalid month" do
        show_monthly_status(month: 13, year: 2026)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "month")).to be_present
      end

      it "returns 422 for an invalid year" do
        show_monthly_status(month: 8, year: 0)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "year")).to be_present
      end
    end

    context "when unauthenticated" do
      subject { show_monthly_status({ month: 8, year: 2026 }, {}) }

      it_behaves_like "an unauthorized API request"
    end
  end

  describe "PATCH /api/v1/monthly_statuses" do
    def update_monthly_status(params, request_headers = headers)
      patch "/api/v1/monthly_statuses", params: params, headers: request_headers, as: :json
    end

    context "when authenticated" do
      it "closes the month and the next GET returns closed" do
        create(:monthly_status, user:, month: 8, year: 2026)

        update_monthly_status(monthly_status: { month: 8, year: 2026, status: "closed" })

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["message"]).to eq("Monthly status updated successfully")
        expect(monthly_status_attributes).to include("status" => "closed")
        expect(MonthlyStatus::Record.find_by!(user_id: user.id, month: 8, year: 2026).status).to eq("closed")

        get "/api/v1/monthly_statuses", params: { month: 8, year: 2026 }, headers: headers

        expect(response).to have_http_status(:ok)
        expect(monthly_status_attributes).to include("status" => "closed")
      end

      it "reopens a closed month" do
        create(:monthly_status, :closed, user:, month: 8, year: 2026)

        update_monthly_status(monthly_status: { month: 8, year: 2026, status: "open" })

        expect(response).to have_http_status(:ok)
        expect(monthly_status_attributes).to include("status" => "open")
        expect(MonthlyStatus::Record.find_by!(user_id: user.id, month: 8, year: 2026).status).to eq("open")
      end

      it "is idempotent when the same status is sent" do
        monthly_status = create(:monthly_status, :closed, user:, month: 8, year: 2026)

        update_monthly_status(monthly_status: { month: 8, year: 2026, status: "closed" })

        expect(response).to have_http_status(:ok)
        expect(monthly_status_attributes).to include("id" => monthly_status.id, "status" => "closed")
      end

      it "creates a closed row when the month is missing" do
        expect {
          update_monthly_status(monthly_status: { month: 8, year: 2026, status: "closed" })
        }.to change(MonthlyStatus::Record, :count).by(1)

        expect(response).to have_http_status(:ok)
        expect(monthly_status_attributes).to include(
          "month" => 8,
          "year" => 2026,
          "status" => "closed"
        )
        expect(MonthlyStatus::Record.find_by!(user_id: user.id, month: 8, year: 2026).status).to eq("closed")
      end

      it "returns 422 for an invalid status" do
        update_monthly_status(monthly_status: { month: 8, year: 2026, status: "archived" })

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "status")).to eq([ "is not a valid status" ])
      end
    end

    context "when unauthenticated" do
      subject { update_monthly_status({ monthly_status: { month: 8, year: 2026, status: "closed" } }, {}) }

      it_behaves_like "an unauthorized API request"
    end
  end
end
