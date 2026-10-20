require "rails_helper"

RSpec.describe "API::V1::User::Email::ConfirmationResends", type: :request do
  describe "POST /api/v1/user/email/confirmation_resends" do
    let(:user) { create(:user) }

    def post_resend(params)
      post "/api/v1/user/email/confirmation_resends", params: params, as: :json
    end

    context "with a valid email" do
      it "creates an email confirmation and enqueues the email" do
        expect { post_resend(email: user.email) }
          .to change(User::Email::Confirmation::Record, :count).by(1)
          .and have_enqueued_mail(UserMailer, :email_verification)

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["status"]).to eq("success")
        expect(response.parsed_body["message"]).to eq(I18n.t("user.email.confirmation_resend.success"))
      end

      it "normalizes the email before looking up the user" do
        post_resend(email: "  #{user.email.upcase}  ")

        expect(response).to have_http_status(:ok)
      end

      it "invalidates previous pending email confirmations" do
        previous_confirmation = create(:user_email_confirmation, user:)

        post_resend(email: user.email)

        expect(previous_confirmation.reload.expires_at).to be < Time.current
        expect(User::Email::Confirmation::Record.pending.where(user_id: user.id).count).to eq(1)
      end
    end

    context "when the email does not exist" do
      it "returns 422 unprocessable entity" do
        post_resend(email: "unknown@example.com")

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "email")).to eq([ "not found" ])
      end
    end

    context "when the user email is already verified" do
      let(:user) { create(:user, :verified) }

      it "returns 422 unprocessable entity" do
        post_resend(email: user.email)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "base")).to eq([ "User email is already verified" ])
      end
    end

    context "when the user is not active" do
      let(:user) { create(:user, :inactive) }

      it "returns 422 unprocessable entity" do
        post_resend(email: user.email)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "base")).to eq([ "User is not active" ])
      end
    end

    context "with an invalid email format" do
      it "returns 422 unprocessable entity" do
        post_resend(email: "not-an-email")

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "email")).to be_present
      end
    end
  end
end
