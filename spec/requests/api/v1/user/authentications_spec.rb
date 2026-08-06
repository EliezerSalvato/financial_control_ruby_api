require "rails_helper"

RSpec.describe "API::V1::User::Authentications", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  describe "POST /api/v1/user/authentications" do
    let(:user) { create(:user, :verified) }
    let(:valid_params) { { email: user.email, password: "password123" } }

    def post_authentication(params)
      post "/api/v1/user/authentications", params: params, as: :json
    end

    context "with valid credentials" do
      it "authenticates the user and creates a session" do
        expect { post_authentication(valid_params) }
          .to change(User::Session::Record, :count).by(1)

        json = response.parsed_body

        expect(response).to have_http_status(:ok)
        expect(json["status"]).to eq("success")
        expect(json.dig("data", "token")).to be_present
        expect(json.dig("data", "user")).to be_present
        expect(json.dig("data", "refresh_token")).to be_nil
        expect(cookies[:refresh_token]).to be_present
      end

      it "stores the request metadata on the session" do
        post "/api/v1/user/authentications",
             params: valid_params,
             headers: { "User-Agent" => "RSpec Browser" },
             as: :json

        session = User::Session::Record.last

        expect(session.ip_address).to be_present
        expect(session.user_agent).to eq("RSpec Browser")
      end

      it "revokes previous active sessions" do
        previous_session = create(:user_session, user:)

        post_authentication(valid_params)

        expect(previous_session.reload.refresh_token_expires_at).to be < Time.current
        expect(User::Session::Record.active.where(user_id: user.id).count).to eq(1)
      end

      it "sets the refresh token cookie as http only and same site lax" do
        post_authentication(valid_params)

        expect(refresh_token_set_cookie).to match(/httponly/i)
        expect(refresh_token_set_cookie).to match(/samesite=lax/i)
      end

      it "creates a short-lived session and a session cookie by default" do
        freeze_time do
          post_authentication(valid_params)

          expect(User::Session::Record.last.refresh_token_expires_at)
            .to be_within(1.second).of(Core::User::Token::SHORT_REFRESH_TOKEN_EXPIRES_IN.from_now)
          expect(persistent_refresh_token_cookie?).to be(false)
        end
      end
    end

    context "with remember_me enabled" do
      it "creates a long-lived session and a persistent refresh token cookie" do
        freeze_time do
          post_authentication(valid_params.merge(remember_me: true))

          expect(response).to have_http_status(:ok)
          expect(cookies[:refresh_token]).to be_present
          expect(User::Session::Record.last.refresh_token_expires_at)
            .to be_within(1.second).of(Core::User::Token::REFRESH_TOKEN_EXPIRES_IN.from_now)
          expect(persistent_refresh_token_cookie?).to be(true)
        end
      end

      # The session itself does not remember the preference, so the client has to send
      # remember_me again on every refresh to keep the long-lived expiration.
      it "keeps the long-lived session when the refresh asks to be remembered" do
        freeze_time do
          post_authentication(valid_params.merge(remember_me: true))

          patch "/api/v1/user/session/refreshes", params: { remember_me: true }, as: :json

          expect(response).to have_http_status(:ok)
          expect(User::Session::Record.last.refresh_token_expires_at)
            .to be_within(1.second).of(Core::User::Token::REFRESH_TOKEN_EXPIRES_IN.from_now)
          expect(persistent_refresh_token_cookie?).to be(true)
        end
      end
    end

    context "with remember_me disabled" do
      it "creates a short-lived session and a session refresh token cookie" do
        freeze_time do
          post_authentication(valid_params.merge(remember_me: false))

          expect(response).to have_http_status(:ok)
          expect(cookies[:refresh_token]).to be_present
          expect(User::Session::Record.last.refresh_token_expires_at)
            .to be_within(1.second).of(Core::User::Token::SHORT_REFRESH_TOKEN_EXPIRES_IN.from_now)
          expect(persistent_refresh_token_cookie?).to be(false)
        end
      end
    end

    context "when the email is normalized" do
      it "authenticates ignoring case and surrounding spaces" do
        post_authentication(valid_params.merge(email: "  #{user.email.upcase}  "))

        expect(response).to have_http_status(:ok)
      end
    end

    context "with invalid credentials" do
      it "rejects an invalid password without creating a session" do
        expect { post_authentication(valid_params.merge(password: "wrong-password")) }
          .not_to change(User::Session::Record, :count)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body["status"]).to eq("error")
        expect(response.parsed_body.dig("details", "base")).to be_present
      end

      it "rejects an unknown email" do
        post_authentication(valid_params.merge(email: "unknown@example.com"))

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "base")).to be_present
      end
    end

    context "when the user email is not verified" do
      let(:user) { create(:user) }

      it "returns 422 unprocessable entity" do
        post_authentication(valid_params)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "base")).to be_present
      end
    end

    context "when the user is not active" do
      let(:user) { create(:user, :verified, :inactive) }

      it "returns 422 unprocessable entity" do
        post_authentication(valid_params)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "base")).to be_present
      end
    end

    context "with missing params" do
      it "rejects a blank email" do
        post_authentication(valid_params.merge(email: ""))

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "email")).to be_present
      end

      it "rejects a blank password" do
        post_authentication(valid_params.merge(password: ""))

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "password")).to be_present
      end
    end
  end
end
