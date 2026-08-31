require "rails_helper"

RSpec.describe "API::V1::User::Session::Refreshes", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  describe "PATCH /api/v1/user/session/refreshes" do
    let(:user) { create(:user, :verified) }
    let(:refresh_token) { User::Adapters.token.generate }
    let!(:session) { create(:user_session, user:, refresh_token:) }

    def patch_refresh(params = {})
      patch "/api/v1/user/session/refreshes", params: params, as: :json
    end

    context "with a valid refresh token cookie" do
      before { set_refresh_token_cookie(refresh_token) }

      it "returns a new session token and rotates the refresh token" do
        expect { patch_refresh }
          .to change { session.reload.refresh_token_digest }

        json = response.parsed_body

        expect(response).to have_http_status(:ok)
        expect(json["status"]).to eq("success")
        expect(json.dig("data", "token")).to be_present
        expect(json.dig("data", "user")).to be_present
        expect(json.dig("data", "user", "data", "attributes", "configs")).to eq({})
        expect(json.dig("data", "refresh_token")).to be_nil
        expect(cookies[:refresh_token]).to be_present
      end

      it "rejects the rotated refresh token when it is reused" do
        patch_refresh

        expect(response).to have_http_status(:ok)

        set_refresh_token_cookie(refresh_token)
        patch_refresh

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "base")).to eq([ "Refresh token is invalid" ])
      end

      it "keeps the session short-lived and the cookie tied to the browser session by default" do
        freeze_time do
          patch_refresh

          expect(session.reload.refresh_token_expires_at)
            .to be_within(1.second).of(Core::User::Token::SHORT_REFRESH_TOKEN_EXPIRES_IN.from_now)
          expect(persistent_refresh_token_cookie?).to be(false)
        end
      end

      it "extends the session and persists the cookie when remember_me is requested" do
        freeze_time do
          patch_refresh(remember_me: true)

          expect(response).to have_http_status(:ok)
          expect(session.reload.refresh_token_expires_at)
            .to be_within(1.second).of(Core::User::Token::REFRESH_TOKEN_EXPIRES_IN.from_now)
          expect(persistent_refresh_token_cookie?).to be(true)
        end
      end

      it "accepts remember_me sent as a string" do
        freeze_time do
          patch_refresh(remember_me: "true")

          expect(session.reload.refresh_token_expires_at)
            .to be_within(1.second).of(Core::User::Token::REFRESH_TOKEN_EXPIRES_IN.from_now)
          expect(persistent_refresh_token_cookie?).to be(true)
        end
      end

      it "shortens a long-lived session when remember_me is not requested" do
        freeze_time do
          session.update!(refresh_token_expires_at: Core::User::Token::REFRESH_TOKEN_EXPIRES_IN.from_now)

          patch_refresh(remember_me: false)

          expect(session.reload.refresh_token_expires_at)
            .to be_within(1.second).of(Core::User::Token::SHORT_REFRESH_TOKEN_EXPIRES_IN.from_now)
          expect(persistent_refresh_token_cookie?).to be(false)
        end
      end
    end

    context "with an invalid refresh token cookie" do
      before { set_refresh_token_cookie("invalid-token") }

      it "returns 422 unprocessable entity" do
        patch_refresh

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body["status"]).to eq("error")
        expect(response.parsed_body.dig("details", "base")).to be_present
      end
    end

    context "with an expired refresh token" do
      let!(:session) { create(:user_session, :expired, user:, refresh_token:) }

      before { set_refresh_token_cookie(refresh_token) }

      it "returns 422 unprocessable entity" do
        patch_refresh

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "base")).to be_present
      end
    end

    context "when the user is not active" do
      let(:user) { create(:user, :verified, :inactive) }

      before { set_refresh_token_cookie(refresh_token) }

      it "returns 422 unprocessable entity" do
        patch_refresh

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "base")).to eq([ "User is not active" ])
      end
    end

    # Unlike sign in, a refresh does not require a verified email: changing the email
    # unverifies the account and the user is expected to keep the session going.
    context "when the user email is not verified" do
      let(:user) { create(:user) }

      before { set_refresh_token_cookie(refresh_token) }

      it "refreshes the session" do
        patch_refresh

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body.dig("data", "token")).to be_present
      end
    end

    context "with a blank refresh token cookie" do
      it "returns 422 unprocessable entity" do
        patch_refresh

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "refresh_token")).to be_present
      end
    end
  end
end
