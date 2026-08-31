require "rails_helper"

RSpec.describe "API::V1::User::Registrations", type: :request do
  describe "POST /api/v1/user/registrations" do
    let(:valid_params) do
      {
        first_name: "John",
        last_name: "Doe",
        email: "john.doe@example.com",
        password: "password123",
        password_confirmation: "password123"
      }
    end

    def post_registration(params)
      post "/api/v1/user/registrations", params: params, as: :json
    end

    context "with valid params" do
      it "registers the user and enqueues the confirmation email" do
        expect { post_registration(valid_params) }
          .to change(User::Record, :count).by(1)
          .and change(User::Email::Confirmation::Record, :count).by(1)
          .and have_enqueued_mail(UserMailer, :email_verification)

        user = User::Record.last
        json = response.parsed_body
        attributes = json.dig("data", "user", "data", "attributes")

        expect(response).to have_http_status(:created)
        expect(json["status"]).to eq("success")
        expect(user).to have_attributes(
          first_name: "John",
          last_name: "Doe",
          email: "john.doe@example.com",
          verified: false
        )
        expect(attributes).to include(
          "first_name" => "John",
          "last_name" => "Doe",
          "email" => "john.doe@example.com",
          "configs" => {}
        )
        expect(attributes.keys).to contain_exactly("id", "first_name", "last_name", "email", "configs")
        expect(User::Email::Confirmation::Record.last.new_email).to eq("john.doe@example.com")
      end
    end

    context "with attributes that need normalization" do
      it "strips names and downcases/strips the email" do
        post_registration(
          valid_params.merge(
            first_name: "  John  ",
            last_name: "  Doe  ",
            email: "  John.Doe@Example.COM  "
          )
        )

        user = User::Record.last
        expect(user).to have_attributes(
          first_name: "John",
          last_name: "Doe",
          email: "john.doe@example.com"
        )
      end
    end

    context "when the email is already taken" do
      before { create(:user, email: "john.doe@example.com") }

      it "does not create a new user and returns an email taken error" do
        expect { post_registration(valid_params) }.not_to change(User::Record, :count)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body["status"]).to eq("error")
        expect(response.parsed_body.dig("details", "email")).to include("has already been taken")
      end
    end

    context "with invalid params" do
      it "rejects a blank first name" do
        post_registration(valid_params.merge(first_name: ""))

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "first_name")).to be_present
      end

      it "rejects a blank last name" do
        post_registration(valid_params.merge(last_name: ""))

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "last_name")).to be_present
      end

      it "rejects an invalid email format" do
        post_registration(valid_params.merge(email: "not-an-email"))

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "email")).to be_present
      end

      it "rejects a password shorter than the minimum length" do
        post_registration(valid_params.merge(password: "short", password_confirmation: "short"))

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "password")).to be_present
      end

      it "rejects a mismatched password confirmation" do
        post_registration(valid_params.merge(password_confirmation: "different123"))

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "password_confirmation")).to be_present
      end

      it "does not persist a user when validation fails" do
        expect { post_registration(valid_params.merge(email: "not-an-email")) }
          .not_to change(User::Record, :count)
      end
    end
  end
end
