require "rails_helper"

RSpec.describe "API::V1::User::Email::Changes", type: :request do
  describe "PATCH /api/v1/user/email/changes" do
    let(:user) { create(:user, :verified) }
    let(:valid_params) { { current_password: "password123", new_email: "new.email@example.com" } }

    def update_email(params, headers)
      patch "/api/v1/user/email/changes", params: params, headers: headers, as: :json
    end

    context "when authenticated" do
      let(:headers) { auth_headers_for(user) }

      context "with valid params" do
        it "changes the email, creates a confirmation, and enqueues the email" do
          expect { update_email(valid_params, headers) }
            .to change(User::Email::Confirmation::Record, :count).by(1)
            .and have_enqueued_mail(UserMailer, :email_verification)

          expect(response).to have_http_status(:ok)
          expect(response.parsed_body["status"]).to eq("success")
          expect(user.reload).to have_attributes(email: "new.email@example.com", verified: false)
        end

        it "normalizes the new email" do
          update_email(valid_params.merge(new_email: "  New.Email@Example.COM  "), headers)

          expect(response).to have_http_status(:ok)
          expect(user.reload.email).to eq("new.email@example.com")
        end

        it "invalidates previous pending email confirmations" do
          previous_confirmation = create(:user_email_confirmation, user:)

          update_email(valid_params, headers)

          expect(previous_confirmation.reload.expires_at).to be < Time.current
          expect(User::Email::Confirmation::Record.pending.where(user_id: user.id).count).to eq(1)
        end

        it "records the previous email on the confirmation and sends it to the new address" do
          original_email = user.email

          expect { update_email(valid_params, headers) }
            .to have_enqueued_mail(UserMailer, :email_verification)
            .with(a_hash_including(params: a_hash_including(email: "new.email@example.com")))

          expect(User::Email::Confirmation::Record.last).to have_attributes(
            old_email: original_email,
            new_email: "new.email@example.com"
          )
        end

        it "revokes the active sessions" do
          create(:user_session, user:)

          update_email(valid_params, headers)

          expect(User::Session::Record.active.where(user_id: user.id)).to be_empty
        end
      end

      context "with an incorrect current password" do
        it "does not change the email" do
          original_email = user.email

          update_email(valid_params.merge(current_password: "wrong-password"), headers)

          expect(response).to have_http_status(:unprocessable_content)
          expect(response.parsed_body.dig("details", "current_password")).to be_present
          expect(user.reload.email).to eq(original_email)
        end
      end

      context "when the new email is the same as the current one" do
        it "returns 422 unprocessable entity" do
          update_email(valid_params.merge(new_email: user.email), headers)

          expect(response).to have_http_status(:unprocessable_content)
          expect(response.parsed_body.dig("details", "base")).to be_present
        end
      end

      context "when the new email is already taken" do
        before { create(:user, email: "taken@example.com") }

        it "returns 422 unprocessable entity" do
          update_email(valid_params.merge(new_email: "taken@example.com"), headers)

          expect(response).to have_http_status(:unprocessable_content)
          expect(response.parsed_body.dig("details", "new_email")).to be_present
        end
      end

      context "with an invalid email format" do
        it "returns 422 unprocessable entity" do
          update_email(valid_params.merge(new_email: "not-an-email"), headers)

          expect(response).to have_http_status(:unprocessable_content)
          expect(response.parsed_body.dig("details", "new_email")).to be_present
        end
      end

      context "with missing params" do
        it "rejects a blank current password" do
          update_email(valid_params.merge(current_password: ""), headers)

          expect(response).to have_http_status(:unprocessable_content)
          expect(response.parsed_body.dig("details", "current_password")).to be_present
        end

        it "rejects a blank new email" do
          update_email(valid_params.merge(new_email: ""), headers)

          expect(response).to have_http_status(:unprocessable_content)
          expect(response.parsed_body.dig("details", "new_email")).to be_present
        end
      end
    end

    context "when unauthenticated" do
      subject { update_email(valid_params, {}) }

      it_behaves_like "an unauthorized API request"
    end

    context "when the user is deactivated after the token is issued" do
      subject do
        headers = auth_headers_for(user)

        user.update!(active: false)

        update_email(valid_params, headers)
      end

      it_behaves_like "an unauthorized API request"

      it "does not change the email" do
        original_email = user.email

        subject

        expect(user.reload.email).to eq(original_email)
      end
    end
  end
end
