require "rails_helper"

RSpec.describe "API::V1::User::Password::Changes", type: :request do
  describe "PATCH /api/v1/user/password/changes" do
    let(:user) { create(:user, :verified) }
    let(:valid_params) do
      {
        current_password: "password123",
        password: "new-password123",
        password_confirmation: "new-password123"
      }
    end

    def update_password(params, headers)
      patch "/api/v1/user/password/changes", params: params, headers: headers, as: :json
    end

    context "when authenticated" do
      let(:headers) { auth_headers_for(user) }

      context "with valid params" do
        it "updates the password" do
          update_password(valid_params, headers)

          expect(response).to have_http_status(:ok)
          expect(response.parsed_body["status"]).to eq("success")
          expect(user.reload.authenticate("new-password123")).to be_truthy
        end

        it "invalidates the previous password" do
          update_password(valid_params, headers)

          expect(user.reload.authenticate("password123")).to be(false)
        end

        it "revokes the active sessions" do
          create(:user_session, user:)

          update_password(valid_params, headers)

          expect(User::Session::Record.active.where(user_id: user.id)).to be_empty
        end
      end

      context "with an incorrect current password" do
        it "returns 422 unprocessable entity" do
          update_password(valid_params.merge(current_password: "wrong-password"), headers)

          expect(response).to have_http_status(:unprocessable_content)
          expect(response.parsed_body.dig("details", "current_password")).to be_present
        end
      end

      context "when the new password is the same as the current one" do
        it "returns 422 unprocessable entity" do
          update_password(
            valid_params.merge(password: "password123", password_confirmation: "password123"),
            headers
          )

          expect(response).to have_http_status(:unprocessable_content)
          expect(response.parsed_body.dig("details", "password")).to be_present
        end
      end

      context "with a password shorter than the minimum length" do
        it "returns 422 unprocessable entity" do
          update_password(valid_params.merge(password: "short", password_confirmation: "short"), headers)

          expect(response).to have_http_status(:unprocessable_content)
          expect(response.parsed_body.dig("details", "password")).to be_present
        end
      end

      context "with a mismatched password confirmation" do
        it "returns 422 unprocessable entity" do
          update_password(valid_params.merge(password_confirmation: "different123"), headers)

          expect(response).to have_http_status(:unprocessable_content)
          expect(response.parsed_body.dig("details", "password_confirmation")).to be_present
        end
      end

      context "with missing params" do
        it "rejects a blank current password" do
          update_password(valid_params.merge(current_password: ""), headers)

          expect(response).to have_http_status(:unprocessable_content)
          expect(response.parsed_body.dig("details", "current_password")).to be_present
        end

        it "rejects a blank password" do
          update_password(valid_params.merge(password: "", password_confirmation: ""), headers)

          expect(response).to have_http_status(:unprocessable_content)
          expect(response.parsed_body.dig("details", "password")).to be_present
        end
      end
    end

    context "when unauthenticated" do
      subject { update_password(valid_params, {}) }

      it_behaves_like "an unauthorized API request"
    end

    context "when the user is deactivated after the token is issued" do
      subject do
        headers = auth_headers_for(user)

        user.update!(active: false)

        update_password(valid_params, headers)
      end

      it_behaves_like "an unauthorized API request"

      it "does not change the password" do
        subject

        expect(user.reload.authenticate("password123")).to be_truthy
      end
    end
  end
end
