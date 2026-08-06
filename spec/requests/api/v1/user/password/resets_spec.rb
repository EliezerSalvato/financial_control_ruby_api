require "rails_helper"

RSpec.describe "API::V1::User::Password::Resets", type: :request do
  describe "POST /api/v1/user/password/resets" do
    let(:user) { create(:user, :verified) }

    def post_reset(params)
      post "/api/v1/user/password/resets", params: params, as: :json
    end

    context "with a valid email" do
      it "creates a password reset and enqueues the email" do
        expect { post_reset(email: user.email) }
          .to change(User::Password::Reset::Record, :count).by(1)
          .and have_enqueued_mail(UserMailer, :password_reset)

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["status"]).to eq("success")
      end

      it "normalizes the email before looking up the user" do
        post_reset(email: "  #{user.email.upcase}  ")

        expect(response).to have_http_status(:ok)
      end

      it "invalidates previous pending password resets" do
        previous_reset = create(:user_password_reset, user:)

        post_reset(email: user.email)

        expect(previous_reset.reload.expires_at).to be < Time.current
        expect(User::Password::Reset::Record.pending.where(user_id: user.id).count).to eq(1)
      end
    end

    context "when the email does not exist" do
      it "returns 422 unprocessable entity" do
        post_reset(email: "unknown@example.com")

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "email")).to eq([ "not found" ])
      end
    end

    context "when the user email is not verified" do
      let(:user) { create(:user) }

      it "returns 422 unprocessable entity" do
        post_reset(email: user.email)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "base")).to eq([ "User email is not verified" ])
      end
    end

    context "when the user is not active" do
      let(:user) { create(:user, :verified, :inactive) }

      it "returns 422 unprocessable entity" do
        post_reset(email: user.email)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "base")).to eq([ "User is not active" ])
      end
    end

    context "with an invalid email format" do
      it "returns 422 unprocessable entity" do
        post_reset(email: "not-an-email")

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "email")).to be_present
      end
    end
  end

  describe "PATCH /api/v1/user/password/resets" do
    let(:user) { create(:user, :verified) }
    let(:token) { User::Adapters.token.generate_for(user: User::Mapper.to_entity(user), purpose: :reset_password) }
    let!(:password_reset) { create(:user_password_reset, user:, token:) }
    let!(:session) { create(:user_session, user:) }
    let(:valid_params) do
      { token: token, password: "new-password123", password_confirmation: "new-password123" }
    end

    def patch_reset(params)
      patch "/api/v1/user/password/resets", params: params, as: :json
    end

    context "with valid params" do
      it "resets the password, marks the token as used, and revokes sessions" do
        patch_reset(valid_params)

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["status"]).to eq("success")
        expect(user.reload.authenticate("new-password123")).to be_truthy
        expect(password_reset.reload.reset_at).to be_present
        expect(User::Session::Record.active.where(user_id: user.id)).to be_empty
      end
    end

    context "with an invalid token" do
      it "returns 422 unprocessable entity" do
        patch_reset(valid_params.merge(token: "invalid-token"))

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body["status"]).to eq("error")
        expect(response.parsed_body.dig("details", "base")).to be_present
      end
    end

    context "with an expired token" do
      let!(:password_reset) { create(:user_password_reset, :expired, user:, token:) }

      it "returns 422 unprocessable entity" do
        patch_reset(valid_params)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "base")).to be_present
      end
    end

    context "with an already used token" do
      let!(:password_reset) { create(:user_password_reset, :reset, user:, token:) }

      it "returns 422 unprocessable entity" do
        patch_reset(valid_params)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "base")).to be_present
      end
    end

    context "when the user is not active" do
      let(:user) { create(:user, :verified, :inactive) }

      it "returns 422 unprocessable entity" do
        patch_reset(valid_params)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "base")).to be_present
      end
    end

    context "when the user email is not verified" do
      let(:user) { create(:user) }

      it "returns 422 unprocessable entity" do
        patch_reset(valid_params)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "base")).to be_present
      end
    end

    context "when the new password is the same as the current one" do
      it "returns 422 unprocessable entity" do
        patch_reset(valid_params.merge(password: "password123", password_confirmation: "password123"))

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "password")).to be_present
      end
    end

    context "with a password shorter than the minimum length" do
      it "returns 422 unprocessable entity" do
        patch_reset(valid_params.merge(password: "short", password_confirmation: "short"))

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "password")).to be_present
      end
    end

    context "with a mismatched password confirmation" do
      it "returns 422 unprocessable entity" do
        patch_reset(valid_params.merge(password_confirmation: "different123"))

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "password_confirmation")).to be_present
      end
    end
  end
end
