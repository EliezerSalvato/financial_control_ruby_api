require "rails_helper"

RSpec.describe "API facade fallback branches", type: :request do
  let(:user) { create(:user, :verified) }
  let(:headers) { auth_headers_for(user) }
  let(:id) { UUID.generate }

  def input_failure(process_class)
    input = process_class::Input.new
    input.errors.add(:base, :invalid)
    Solid::Failure(:invalid_input, input:)
  end

  def unexpected_failure
    Solid::Failure(:unexpected)
  end

  describe "accounts" do
    it "returns bad request when listing fails with invalid_filters" do
      allow(Account).to receive(:list).and_return(Solid::Failure(:invalid_filters))

      get "/api/v1/accounts", headers: headers

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body["message"]).to eq(I18n.t("account.errors.invalid_filters"))
    end

    it "returns bad request when listing fails unexpectedly" do
      allow(Account).to receive(:list).and_return(unexpected_failure)

      get "/api/v1/accounts", headers: headers

      expect(response).to have_http_status(:bad_request)
    end

    it "returns not found when showing fails unexpectedly" do
      allow(Account).to receive(:find).and_return(unexpected_failure)

      get "/api/v1/accounts/#{id}", headers: headers

      expect(response).to have_http_status(:not_found)
    end

    it "returns unprocessable content when creating fails unexpectedly" do
      allow(Account).to receive(:create).and_return(unexpected_failure)

      post "/api/v1/accounts", params: { account: { name: "Wallet", kind: "cash", color: "#3B82F6" } }, headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["message"]).to eq(I18n.t("account.creation.failure"))
    end

    it "returns unprocessable content when updating fails unexpectedly" do
      allow(Account).to receive(:update).and_return(unexpected_failure)

      patch "/api/v1/accounts/#{id}", params: { account: { name: "Cash" } }, headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["message"]).to eq(I18n.t("account.update.failure"))
    end

    it "returns unprocessable content when destroying fails unexpectedly" do
      allow(Account).to receive(:destroy).and_return(unexpected_failure)

      delete "/api/v1/accounts/#{id}", headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["message"]).to eq(I18n.t("account.deletion.failure"))
    end
  end

  describe "categories" do
    it "returns bad request when listing fails with invalid_filters" do
      allow(Category).to receive(:list).and_return(Solid::Failure(:invalid_filters))

      get "/api/v1/categories", headers: headers

      expect(response).to have_http_status(:bad_request)
    end

    it "returns bad request when listing fails unexpectedly" do
      allow(Category).to receive(:list).and_return(unexpected_failure)

      get "/api/v1/categories", headers: headers

      expect(response).to have_http_status(:bad_request)
    end

    it "returns not found when showing fails unexpectedly" do
      allow(Category).to receive(:find).and_return(unexpected_failure)

      get "/api/v1/categories/#{id}", headers: headers

      expect(response).to have_http_status(:not_found)
    end

    it "returns unprocessable content when creating fails unexpectedly" do
      allow(Category).to receive(:create).and_return(unexpected_failure)

      post "/api/v1/categories", params: { category: { name: "Food", color: "#3B82F6" } }, headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "returns unprocessable content when updating fails unexpectedly" do
      allow(Category).to receive(:update).and_return(unexpected_failure)

      patch "/api/v1/categories/#{id}", params: { category: { name: "Groceries" } }, headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "returns unprocessable content when destroying fails unexpectedly" do
      allow(Category).to receive(:destroy).and_return(unexpected_failure)

      delete "/api/v1/categories/#{id}", headers: headers

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "institutions" do
    it "returns bad request when listing fails with invalid_filters" do
      allow(Institution).to receive(:list).and_return(Solid::Failure(:invalid_filters))

      get "/api/v1/institutions", headers: headers

      expect(response).to have_http_status(:bad_request)
    end

    it "returns bad request when listing fails unexpectedly" do
      allow(Institution).to receive(:list).and_return(unexpected_failure)

      get "/api/v1/institutions", headers: headers

      expect(response).to have_http_status(:bad_request)
    end

    it "returns not found when showing fails unexpectedly" do
      allow(Institution).to receive(:find).and_return(unexpected_failure)

      get "/api/v1/institutions/#{id}", headers: headers

      expect(response).to have_http_status(:not_found)
    end

    it "returns unprocessable content when creating fails unexpectedly" do
      allow(Institution).to receive(:create).and_return(unexpected_failure)

      post "/api/v1/institutions", params: { institution: { name: "Nubank", color: "#820AD1" } }, headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "returns unprocessable content when updating fails unexpectedly" do
      allow(Institution).to receive(:update).and_return(unexpected_failure)

      patch "/api/v1/institutions/#{id}", params: { institution: { name: "Bank" } }, headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "returns unprocessable content when destroying fails unexpectedly" do
      allow(Institution).to receive(:destroy).and_return(unexpected_failure)

      delete "/api/v1/institutions/#{id}", headers: headers

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "tags" do
    it "returns bad request when listing fails with invalid_filters" do
      allow(Tag).to receive(:list).and_return(Solid::Failure(:invalid_filters))

      get "/api/v1/tags", headers: headers

      expect(response).to have_http_status(:bad_request)
    end

    it "returns bad request when listing fails unexpectedly" do
      allow(Tag).to receive(:list).and_return(unexpected_failure)

      get "/api/v1/tags", headers: headers

      expect(response).to have_http_status(:bad_request)
    end

    it "returns not found when showing fails unexpectedly" do
      allow(Tag).to receive(:find).and_return(unexpected_failure)

      get "/api/v1/tags/#{id}", headers: headers

      expect(response).to have_http_status(:not_found)
    end

    it "returns unprocessable content when creating fails unexpectedly" do
      allow(Tag).to receive(:create).and_return(unexpected_failure)

      post "/api/v1/tags", params: { tag: { name: "Trip", color: "#3B82F6" } }, headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "returns unprocessable content when updating fails unexpectedly" do
      allow(Tag).to receive(:update).and_return(unexpected_failure)

      patch "/api/v1/tags/#{id}", params: { tag: { name: "Travel" } }, headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "returns model errors when destroying fails with input" do
      allow(Tag).to receive(:destroy).and_return(input_failure(Core::Tag::Deletion))

      delete "/api/v1/tags/#{id}", headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["details"]).to be_present
    end

    it "returns unprocessable content when destroying fails unexpectedly" do
      allow(Tag).to receive(:destroy).and_return(unexpected_failure)

      delete "/api/v1/tags/#{id}", headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["message"]).to eq(I18n.t("tag.deletion.failure"))
    end
  end

  describe "credit cards" do
    it "returns bad request when listing fails with invalid_filters" do
      allow(CreditCard).to receive(:list).and_return(Solid::Failure(:invalid_filters))

      get "/api/v1/credit_cards", headers: headers

      expect(response).to have_http_status(:bad_request)
    end

    it "returns bad request when listing fails unexpectedly" do
      allow(CreditCard).to receive(:list).and_return(unexpected_failure)

      get "/api/v1/credit_cards", headers: headers

      expect(response).to have_http_status(:bad_request)
    end

    it "returns bad request when listing invoice settlements fails unexpectedly" do
      allow(CreditCard).to receive(:list_invoice_settlements).and_return(unexpected_failure)

      get "/api/v1/credit_cards/invoice_settlements", params: { month: 8, year: 2026 }, headers: headers

      expect(response).to have_http_status(:bad_request)
    end

    it "returns not found when showing fails unexpectedly" do
      allow(CreditCard).to receive(:find).and_return(unexpected_failure)

      get "/api/v1/credit_cards/#{id}", headers: headers

      expect(response).to have_http_status(:not_found)
    end

    it "returns unprocessable content when creating fails unexpectedly" do
      allow(CreditCard).to receive(:create).and_return(unexpected_failure)

      post "/api/v1/credit_cards",
           params: { credit_card: { name: "Platinum", institution_id: id, default_payment_account_id: id, closing_day: 10, due_day: 17, network: "mastercard" } },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "returns unprocessable content when updating fails unexpectedly" do
      allow(CreditCard).to receive(:update).and_return(unexpected_failure)

      patch "/api/v1/credit_cards/#{id}", params: { credit_card: { name: "Gold" } }, headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "returns unprocessable content when destroying fails unexpectedly" do
      allow(CreditCard).to receive(:destroy).and_return(unexpected_failure)

      delete "/api/v1/credit_cards/#{id}", headers: headers

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "transactions" do
    it "returns bad request when listing fails with invalid_filters" do
      allow(Transaction).to receive(:list).and_return(Solid::Failure(:invalid_filters))

      get "/api/v1/transactions", headers: headers

      expect(response).to have_http_status(:bad_request)
    end

    it "returns model errors when listing fails with invalid input" do
      allow(Transaction).to receive(:list).and_return(input_failure(Core::Transaction::Listing))

      get "/api/v1/transactions", headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["details"]).to be_present
    end

    it "returns bad request when listing fails unexpectedly" do
      allow(Transaction).to receive(:list).and_return(unexpected_failure)

      get "/api/v1/transactions", headers: headers

      expect(response).to have_http_status(:bad_request)
    end

    it "returns bad request when listing settled transactions fails unexpectedly" do
      allow(Transaction).to receive(:list_settled).and_return(unexpected_failure)

      get "/api/v1/transactions/settled", params: { month: 8, year: 2026 }, headers: headers

      expect(response).to have_http_status(:bad_request)
    end

    it "returns not found when showing fails unexpectedly" do
      allow(Transaction).to receive(:find).and_return(unexpected_failure)

      get "/api/v1/transactions/#{id}", headers: headers

      expect(response).to have_http_status(:not_found)
    end

    it "returns unprocessable content when creating fails unexpectedly" do
      allow(Transaction).to receive(:create).and_return(unexpected_failure)

      post "/api/v1/transactions",
           params: { transaction: { description: "Rent", kind: "expense", payment_method: "pix", recurrence_type: "one_time", starts_on: "2026-08-11", value: 100 } },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "returns unprocessable content when updating fails unexpectedly" do
      allow(Transaction).to receive(:update).and_return(unexpected_failure)

      patch "/api/v1/transactions/#{id}", params: { transaction: { description: "Updated" } }, headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "returns unprocessable content when cancelling fails unexpectedly" do
      allow(Transaction).to receive(:cancel).and_return(unexpected_failure)

      post "/api/v1/transactions/#{id}/cancel", headers: headers

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "returns unprocessable content when destroying fails unexpectedly" do
      allow(Transaction).to receive(:destroy).and_return(unexpected_failure)

      delete "/api/v1/transactions/#{id}", headers: headers

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "returns unprocessable content when changing recurrence fails unexpectedly" do
      allow(Transaction).to receive(:change_recurrence).and_return(unexpected_failure)

      post "/api/v1/transactions/#{id}/recurrences",
           params: { transaction_recurrence: { starts_on: "2026-08-11", value: 50 } },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "monthly statements" do
    it "returns bad request when listing fails unexpectedly" do
      allow(MonthlyStatement).to receive(:list).and_return(unexpected_failure)

      get "/api/v1/monthly_statements", params: { month: 8, year: 2026 }, headers: headers

      expect(response).to have_http_status(:bad_request)
    end

    it "returns bad request when listing transfers fails unexpectedly" do
      allow(MonthlyStatement).to receive(:list_transfers).and_return(unexpected_failure)

      get "/api/v1/monthly_statements/transfers", params: { month: 8, year: 2026 }, headers: headers

      expect(response).to have_http_status(:bad_request)
    end
  end

  describe "monthly statuses" do
    it "returns not found when showing fails unexpectedly" do
      allow(MonthlyStatus).to receive(:find).and_return(unexpected_failure)

      get "/api/v1/monthly_statuses", params: { month: 8, year: 2026 }, headers: headers

      expect(response).to have_http_status(:not_found)
    end

    it "returns unprocessable content when updating fails unexpectedly" do
      allow(MonthlyStatus).to receive(:update).and_return(unexpected_failure)

      patch "/api/v1/monthly_statuses", params: { monthly_status: { month: 8, year: 2026, status: "open" } }, headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "notifications" do
    it "returns bad request when listing fails unexpectedly" do
      allow(Notification).to receive(:list).and_return(unexpected_failure)

      get "/api/v1/notifications", headers: headers

      expect(response).to have_http_status(:bad_request)
    end

    it "returns not found when showing fails unexpectedly" do
      allow(Notification).to receive(:find).and_return(unexpected_failure)

      get "/api/v1/notifications/#{id}", headers: headers

      expect(response).to have_http_status(:not_found)
    end

    it "returns model errors when marking as read fails with input" do
      allow(Notification).to receive(:mark_as_read).and_return(input_failure(Core::Notification::MarkAsRead))

      post "/api/v1/notifications/#{id}/read", headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["details"]).to be_present
    end

    it "returns unprocessable content when marking as read fails unexpectedly" do
      allow(Notification).to receive(:mark_as_read).and_return(unexpected_failure)

      post "/api/v1/notifications/#{id}/read", headers: headers

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "returns model errors when marking all as read fails with input" do
      allow(Notification).to receive(:mark_all_as_read).and_return(input_failure(Core::Notification::MarkAllAsRead))

      post "/api/v1/notifications/read_all", headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["details"]).to be_present
    end

    it "returns unprocessable content when marking all as read fails unexpectedly" do
      allow(Notification).to receive(:mark_all_as_read).and_return(unexpected_failure)

      post "/api/v1/notifications/read_all", headers: headers

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "user" do
    it "returns unprocessable content when deleting the account fails unexpectedly" do
      allow(User).to receive(:delete_account).and_return(unexpected_failure)

      delete "/api/v1/user/accounts", params: { password: "password123" }, headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "returns unprocessable content when authentication fails unexpectedly" do
      allow(User).to receive(:authenticate).and_return(unexpected_failure)

      post "/api/v1/user/authentications", params: { email: "a@example.com", password: "password123" }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "returns unprocessable content when changing email fails unexpectedly" do
      allow(User).to receive(:change_email).and_return(unexpected_failure)

      patch "/api/v1/user/email/changes", params: { current_password: "password123", new_email: "new@example.com" }, headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "returns unprocessable content when confirming email fails unexpectedly" do
      allow(User).to receive(:confirm_email).and_return(unexpected_failure)

      post "/api/v1/user/email/confirmations", params: { token: "token" }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "returns unprocessable content when changing password fails unexpectedly" do
      allow(User).to receive(:change_password).and_return(unexpected_failure)

      patch "/api/v1/user/password/changes",
            params: { current_password: "password123", password: "password456", password_confirmation: "password456" },
            headers: headers,
            as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "returns unprocessable content when sending reset instructions fails unexpectedly" do
      allow(User).to receive(:send_reset_password_instructions).and_return(unexpected_failure)

      post "/api/v1/user/password/resets", params: { email: "a@example.com" }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "returns unprocessable content when resetting password fails unexpectedly" do
      allow(User).to receive(:reset_password).and_return(unexpected_failure)

      patch "/api/v1/user/password/resets", params: { token: "token", password: "password456", password_confirmation: "password456" }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "returns unprocessable content when updating the profile fails unexpectedly" do
      allow(User).to receive(:update_profile).and_return(unexpected_failure)

      patch "/api/v1/user/profiles", params: { first_name: "Jane" }, headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "returns unprocessable content when registration fails unexpectedly" do
      allow(User).to receive(:register).and_return(unexpected_failure)

      post "/api/v1/user/registrations",
           params: { first_name: "Jane", last_name: "Doe", email: "jane@example.com", password: "password123", password_confirmation: "password123" },
           as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "returns unprocessable content when refreshing the session fails unexpectedly" do
      allow(User).to receive(:refresh_session).and_return(unexpected_failure)

      patch "/api/v1/user/session/refreshes", as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "returns model errors when revoking sessions fails with input" do
      allow(User).to receive(:revoke_sessions).and_return(input_failure(Core::User::Session::Revoke))

      delete "/api/v1/user/session/revokes", headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["details"]).to be_present
    end

    it "returns unprocessable content when revoking sessions fails unexpectedly" do
      allow(User).to receive(:revoke_sessions).and_return(unexpected_failure)

      delete "/api/v1/user/session/revokes", headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
