require "rails_helper"

RSpec.describe "API::V1::User::Session::Revokes", type: :request do
  describe "DELETE /api/v1/user/session/revokes" do
    let(:user) { create(:user, :verified) }
    let!(:session) { create(:user_session, user:) }

    def delete_revoke(headers)
      delete "/api/v1/user/session/revokes", headers: headers, as: :json
    end

    context "when authenticated" do
      let(:headers) { auth_headers_for(user) }

      it "revokes the active sessions of the user" do
        delete_revoke(headers)

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["status"]).to eq("success")
        expect(User::Session::Record.active.where(user_id: user.id)).to be_empty
      end
    end

    context "when unauthenticated" do
      subject { delete_revoke({}) }

      it_behaves_like "an unauthorized API request"

      it "does not revoke any session" do
        subject

        expect(session.reload.refresh_token_expires_at).to be > Time.current
      end
    end

    context "when the user is deactivated after the token is issued" do
      subject do
        headers = auth_headers_for(user)

        user.update!(active: false)

        delete_revoke(headers)
      end

      it_behaves_like "an unauthorized API request"
    end
  end
end
