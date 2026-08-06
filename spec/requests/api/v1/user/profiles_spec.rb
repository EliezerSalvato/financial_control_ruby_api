require "rails_helper"

RSpec.describe "API::V1::User::Profiles", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  describe "PATCH /api/v1/user/profiles" do
    let(:user) { create(:user, :verified, first_name: "John", last_name: "Doe") }
    let(:valid_params) { { first_name: "Jane", last_name: "Smith" } }

    def update_profile(params, headers)
      patch "/api/v1/user/profiles", params: params, headers: headers, as: :json
    end

    context "when authenticated" do
      let(:headers) { auth_headers_for(user) }

      context "with valid params" do
        it "updates the user names" do
          update_profile(valid_params, headers)

          expect(response).to have_http_status(:ok)
          expect(response.parsed_body["status"]).to eq("success")
          expect(user.reload).to have_attributes(first_name: "Jane", last_name: "Smith")
        end

        it "strips surrounding spaces from the names" do
          update_profile({ first_name: "  Jane  ", last_name: "  Smith  " }, headers)

          expect(user.reload).to have_attributes(first_name: "Jane", last_name: "Smith")
        end
      end

      context "with invalid params" do
        it "rejects a blank first name" do
          update_profile(valid_params.merge(first_name: ""), headers)

          expect(response).to have_http_status(:unprocessable_content)
          expect(response.parsed_body.dig("details", "first_name")).to be_present
        end

        it "rejects a blank last name" do
          update_profile(valid_params.merge(last_name: ""), headers)

          expect(response).to have_http_status(:unprocessable_content)
          expect(response.parsed_body.dig("details", "last_name")).to be_present
        end
      end
    end

    context "when unauthenticated" do
      subject { update_profile(valid_params, {}) }

      it_behaves_like "an unauthorized API request"
    end

    context "with an invalid bearer token" do
      subject { update_profile(valid_params, { "Authorization" => "Bearer invalid-token" }) }

      it_behaves_like "an unauthorized API request"
    end

    context "with an expired bearer token" do
      subject do
        headers = auth_headers_for(user, expires_in: 1.second)

        travel 2.seconds

        update_profile(valid_params, headers)
      end

      it_behaves_like "an unauthorized API request"
    end

    context "with a bearer token signed for another purpose" do
      subject do
        token = User::Adapters.token.sign(
          user: User::Mapper.to_entity(user),
          purpose: :email_confirmation,
          expires_in: Core::User::Token::SESSION_TOKEN_EXPIRES_IN
        )

        update_profile(valid_params, { "Authorization" => "Bearer #{token}" })
      end

      it_behaves_like "an unauthorized API request"
    end

    context "when the user is deactivated after the token is issued" do
      subject do
        headers = auth_headers_for(user)

        user.update!(active: false)

        update_profile(valid_params, headers)
      end

      it_behaves_like "an unauthorized API request"

      it "does not update the profile" do
        subject

        expect(user.reload).to have_attributes(first_name: "John", last_name: "Doe")
      end
    end
  end
end
