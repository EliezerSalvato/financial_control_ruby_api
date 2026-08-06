require "rails_helper"

RSpec.describe "API::V1::User::Email::Confirmations", type: :request do
  describe "POST /api/v1/user/email/confirmations" do
    let(:user) { create(:user) }
    let(:token) { User::Adapters.token.generate_for(user: User::Mapper.to_entity(user), purpose: :email_confirmation) }
    let!(:confirmation) { create(:user_email_confirmation, user:, token:) }

    def post_confirmation(params)
      post "/api/v1/user/email/confirmations", params: params, as: :json
    end

    context "with a valid token" do
      it "confirms the email and marks the confirmation as confirmed" do
        post_confirmation(token: token)

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["status"]).to eq("success")
        expect(user.reload).to be_verified
        expect(confirmation.reload.confirmed_at).to be_present
      end
    end

    context "with an invalid token" do
      it "does not verify the user" do
        post_confirmation(token: "invalid-token")

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body["status"]).to eq("error")
        expect(response.parsed_body.dig("details", "base")).to be_present
        expect(user.reload).not_to be_verified
      end
    end

    context "with an expired token" do
      let!(:confirmation) { create(:user_email_confirmation, :expired, user:, token:) }

      it "returns 422 unprocessable entity" do
        post_confirmation(token: token)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "base")).to be_present
        expect(user.reload).not_to be_verified
      end
    end

    context "with an already confirmed token" do
      let!(:confirmation) { create(:user_email_confirmation, :confirmed, user:, token:) }

      it "returns 422 unprocessable entity" do
        post_confirmation(token: token)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "base")).to be_present
      end
    end

    context "with a blank token" do
      it "returns 422 unprocessable entity" do
        post_confirmation(token: "")

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "token")).to be_present
      end
    end
  end
end
