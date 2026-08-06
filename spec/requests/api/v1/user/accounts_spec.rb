require "rails_helper"

RSpec.describe "API::V1::User::Accounts", type: :request do
  describe "DELETE /api/v1/user/accounts" do
    let!(:user) { create(:user, :verified) }
    let(:valid_params) { { password: "password123" } }

    def delete_account(params, headers)
      delete "/api/v1/user/accounts", params: params, headers: headers, as: :json
    end

    context "when authenticated" do
      let(:headers) { auth_headers_for(user) }

      context "with the correct password" do
        it "destroys the user" do
          expect { delete_account(valid_params, headers) }
            .to change(User::Record, :count).by(-1)

          expect(response).to have_http_status(:ok)
          expect(response.parsed_body["status"]).to eq("success")
        end
      end

      context "with an incorrect password" do
        it "does not destroy the user" do
          expect { delete_account(valid_params.merge(password: "wrong-password"), headers) }
            .not_to change(User::Record, :count)

          expect(response).to have_http_status(:unprocessable_content)
          expect(response.parsed_body.dig("details", "password")).to be_present
        end
      end

      context "with a blank password" do
        it "returns 422 unprocessable entity" do
          delete_account(valid_params.merge(password: ""), headers)

          expect(response).to have_http_status(:unprocessable_content)
          expect(response.parsed_body.dig("details", "password")).to be_present
        end
      end
    end

    context "when unauthenticated" do
      subject { delete_account(valid_params, {}) }

      it_behaves_like "an unauthorized API request"
    end

    context "when the user is deactivated after the token is issued" do
      subject do
        headers = auth_headers_for(user)

        user.update!(active: false)

        delete_account(valid_params, headers)
      end

      it_behaves_like "an unauthorized API request"

      it "does not destroy the user" do
        expect { subject }.not_to change(User::Record, :count)
      end
    end
  end
end
