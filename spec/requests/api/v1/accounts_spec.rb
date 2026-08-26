require "rails_helper"

RSpec.describe "API::V1::Accounts", type: :request do
  let(:user) { create(:user, :verified) }
  let(:headers) { auth_headers_for(user) }

  def account_attributes(payload)
    payload.dig("data", "attributes")
  end

  describe "GET /api/v1/accounts" do
    def list_accounts(query = {}, request_headers = headers)
      get "/api/v1/accounts", params: query, headers: request_headers
    end

    context "when authenticated" do
      let!(:active_account) { create(:account, user:, name: "Wallet", active: true) }
      let!(:inactive_account) { create(:account, :inactive, user:, name: "Archive") }
      let!(:bank_account) { create(:account, :bank_account, user:, name: "Checking", bank_account_type: "checking") }
      let!(:savings_account) { create(:account, :bank_account, user:, name: "Savings", bank_account_type: "savings") }
      let!(:other_user_account) { create(:account, name: "Other") }

      it "returns only the current user's accounts" do
        list_accounts

        ids = response.parsed_body["data"].map { |item| item.dig("attributes", "id") }

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["type"]).to eq("collection")
        expect(ids).to contain_exactly(
          active_account.id,
          inactive_account.id,
          bank_account.id,
          savings_account.id
        )
        expect(ids).not_to include(other_user_account.id)
      end

      it "orders by active desc, name asc by default" do
        list_accounts

        names = response.parsed_body["data"].map { |item| item.dig("attributes", "name") }

        expect(names).to eq(%w[Checking Savings Wallet Archive])
      end

      it "filters by name and active" do
        list_accounts(q: { name_cont: "Wal", active_eq: true })

        names = response.parsed_body["data"].map { |item| item.dig("attributes", "name") }

        expect(names).to eq(%w[Wallet])
      end

      it "filters by kind" do
        list_accounts(q: { kind_eq: "cash" })

        names = response.parsed_body["data"].map { |item| item.dig("attributes", "name") }

        expect(names).to contain_exactly("Wallet", "Archive")
      end

      it "filters by bank account type" do
        list_accounts(q: { bank_account_type_eq: "savings" })

        names = response.parsed_body["data"].map { |item| item.dig("attributes", "name") }

        expect(names).to eq(%w[Savings])
      end

      it "filters by institution id" do
        list_accounts(q: { institution_id_eq: savings_account.institution_id })

        names = response.parsed_body["data"].map { |item| item.dig("attributes", "name") }

        expect(names).to eq(%w[Savings])
      end

      it "filters by current balance" do
        create(:account, user:, name: "Seeded", current_balance: 150.5)

        list_accounts(q: { current_balance_eq: 150.5 })

        names = response.parsed_body["data"].map { |item| item.dig("attributes", "name") }

        expect(names).to eq(%w[Seeded])
      end

      it "filters by allow_negative_balance" do
        create(:account, :allow_negative_balance, user:, name: "Overdraft")

        list_accounts(q: { allow_negative_balance_eq: true })

        names = response.parsed_body["data"].map { |item| item.dig("attributes", "name") }

        expect(names).to eq(%w[Overdraft])
      end

      it "paginates the collection" do
        list_accounts(page: 1, per_page: 1)

        meta = response.parsed_body["meta"]

        expect(response.parsed_body["data"].size).to eq(1)
        expect(meta).to include(
          "page" => 1,
          "per_page" => 1,
          "count" => 4,
          "pages" => 4
        )
      end

      it "ignores unknown filters" do
        list_accounts(q: { unknown_field_eq: "x" })

        ids = response.parsed_body["data"].map { |item| item.dig("attributes", "id") }

        expect(response).to have_http_status(:ok)
        expect(ids).to contain_exactly(
          active_account.id,
          inactive_account.id,
          bank_account.id,
          savings_account.id
        )
      end

      it "supports custom sorting" do
        list_accounts(sort: "name asc")

        names = response.parsed_body["data"].map { |item| item.dig("attributes", "name") }

        expect(names).to eq(%w[Archive Checking Savings Wallet])
      end

      it "returns 422 for invalid pagination" do
        list_accounts(page: 0)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "page")).to be_present
      end
    end

    context "when unauthenticated" do
      subject { list_accounts({}, {}) }

      it_behaves_like "an unauthorized API request"
    end
  end

  describe "GET /api/v1/accounts/:id" do
    let(:account) { create(:account, user:, name: "Wallet") }

    def show_account(id, request_headers = headers)
      get "/api/v1/accounts/#{id}", headers: request_headers
    end

    context "when authenticated" do
      it "returns the account" do
        show_account(account.id)

        attributes = account_attributes(response.parsed_body)

        expect(response).to have_http_status(:ok)
        expect(attributes).to include(
          "id" => account.id,
          "name" => "Wallet",
          "kind" => "cash",
          "color" => "#3B82F6",
          "allow_negative_balance" => false,
          "active" => true
        )
        expect(attributes).not_to include("institution_id", "bank_account_type")
      end

      it "returns institution fields for a bank account" do
        bank_account = create(:account, :bank_account, user:, name: "Checking", bank_account_type: "checking")

        show_account(bank_account.id)

        attributes = account_attributes(response.parsed_body)

        expect(response).to have_http_status(:ok)
        expect(attributes).to include(
          "id" => bank_account.id,
          "name" => "Checking",
          "kind" => "bank_account",
          "institution_id" => bank_account.institution_id,
          "bank_account_type" => "checking"
        )
      end

      it "returns 404 for another user's account" do
        show_account(create(:account).id)

        expect(response).to have_http_status(:not_found)
        expect(response.parsed_body["message"]).to eq("Account not found")
      end
    end

    context "when unauthenticated" do
      subject { show_account(account.id, {}) }

      it_behaves_like "an unauthorized API request"
    end
  end

  describe "POST /api/v1/accounts" do
    def create_account(params, request_headers = headers)
      post "/api/v1/accounts", params: params, headers: request_headers, as: :json
    end

    context "when authenticated" do
      it "creates a cash account" do
        expect {
          create_account(account: { name: "Wallet", kind: "cash", color: "#3B82F6", active: true })
        }.to change(Account::Record, :count).by(1)

        attributes = account_attributes(response.parsed_body)

        expect(response).to have_http_status(:created)
        expect(response.parsed_body["message"]).to eq("Account created successfully")
        expect(attributes).to include(
          "name" => "Wallet",
          "kind" => "cash",
          "color" => "#3B82F6",
          "allow_negative_balance" => false,
          "active" => true
        )
        expect(attributes).not_to include("institution_id", "bank_account_type")
      end

      it "creates a bank account" do
        institution = create(:institution, user:)

        create_account(
          account: {
            name: "Checking",
            kind: "bank_account",
            institution_id: institution.id,
            bank_account_type: "checking",
            color: "#820AD1"
          }
        )

        attributes = account_attributes(response.parsed_body)

        expect(response).to have_http_status(:created)
        expect(attributes).to include(
          "name" => "Checking",
          "kind" => "bank_account",
          "institution_id" => institution.id,
          "bank_account_type" => "checking",
          "color" => "#820AD1"
        )
      end

      it "defaults active to true, allow_negative_balance to false, and current_balance to 0" do
        create_account(account: { name: "Wallet", kind: "cash", color: "#3B82F6" })

        attributes = account_attributes(response.parsed_body)

        expect(attributes["active"]).to be(true)
        expect(attributes["allow_negative_balance"]).to be(false)
        expect(attributes["current_balance"].to_d).to eq(0)
      end

      it "creates with allow_negative_balance enabled" do
        create_account(account: { name: "Wallet", kind: "cash", color: "#3B82F6", allow_negative_balance: true })

        expect(account_attributes(response.parsed_body)["allow_negative_balance"]).to be(true)
      end

      it "strips the name" do
        create_account(account: { name: "  Wallet  ", kind: "cash", color: "#3B82F6" })

        expect(account_attributes(response.parsed_body)["name"]).to eq("Wallet")
      end

      it "ignores institution fields for cash via strong parameters" do
        institution = create(:institution, user:)

        create_account(
          account: {
            name: "Wallet",
            kind: "cash",
            color: "#3B82F6",
            institution_id: institution.id,
            bank_account_type: "checking"
          }
        )

        attributes = account_attributes(response.parsed_body)

        expect(response).to have_http_status(:created)
        expect(attributes).not_to include("institution_id", "bank_account_type")
      end

      it "rejects a bank account without institution_id" do
        create_account(
          account: {
            name: "Checking",
            kind: "bank_account",
            bank_account_type: "checking",
            color: "#820AD1"
          }
        )

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "institution_id")).to be_present
      end

      it "rejects a bank account with another user's institution" do
        create_account(
          account: {
            name: "Checking",
            kind: "bank_account",
            institution_id: create(:institution).id,
            bank_account_type: "checking",
            color: "#820AD1"
          }
        )

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "institution_id")).to be_present
      end

      it "rejects a bank account with an inactive institution" do
        institution = create(:institution, :inactive, user:)

        create_account(
          account: {
            name: "Checking",
            kind: "bank_account",
            institution_id: institution.id,
            bank_account_type: "checking",
            color: "#820AD1"
          }
        )

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "institution_id")).to eq([ "is inactive" ])
      end

      it "rejects a blank name" do
        create_account(account: { name: "", kind: "cash", color: "#3B82F6" })

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "name")).to be_present
      end

      it "rejects an invalid color" do
        create_account(account: { name: "Wallet", kind: "cash", color: "blue" })

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "color")).to be_present
      end

      it "rejects a duplicate name for the same user" do
        create(:account, user:, name: "Wallet")

        create_account(account: { name: "wallet", kind: "cash", color: "#EF4444" })

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "name")).to be_present
      end

      it "returns 400 when the account param is missing" do
        create_account({})

        expect(response).to have_http_status(:bad_request)
      end
    end

    context "when unauthenticated" do
      subject { create_account({ account: { name: "Wallet", kind: "cash", color: "#3B82F6" } }, {}) }

      it_behaves_like "an unauthorized API request"
    end
  end

  describe "PATCH /api/v1/accounts/:id" do
    let(:account) { create(:account, user:, name: "Wallet", color: "#3B82F6", active: true) }

    def update_account(id, params, request_headers = headers)
      patch "/api/v1/accounts/#{id}", params: params, headers: request_headers, as: :json
    end

    context "when authenticated" do
      it "updates the account" do
        update_account(account.id, account: { name: "Cash", color: "#10B981", active: false })

        attributes = account_attributes(response.parsed_body)

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["message"]).to eq("Account updated successfully")
        expect(attributes).to include(
          "name" => "Cash",
          "color" => "#10B981",
          "active" => false
        )
        expect(account.reload).to have_attributes(name: "Cash", color: "#10B981", active: false)
      end

      it "updates allow_negative_balance" do
        update_account(account.id, account: { allow_negative_balance: true })

        expect(response).to have_http_status(:ok)
        expect(account_attributes(response.parsed_body)["allow_negative_balance"]).to be(true)
        expect(account.reload.allow_negative_balance).to be(true)
      end

      it "allows partial updates" do
        update_account(account.id, account: { active: false })

        expect(response).to have_http_status(:ok)
        expect(account.reload).to have_attributes(name: "Wallet", color: "#3B82F6", active: false)
      end

      it "ignores institution fields when updating a cash account" do
        institution = create(:institution, user:)

        update_account(
          account.id,
          account: { name: "Cash", institution_id: institution.id, bank_account_type: "checking" }
        )

        expect(response).to have_http_status(:ok)
        expect(account.reload).to have_attributes(
          name: "Cash",
          institution_id: nil,
          bank_account_type: nil
        )
      end

      it "updates a bank account institution fields" do
        bank_account = create(:account, :bank_account, user:, name: "Checking")
        new_institution = create(:institution, user:, name: "Other Bank")

        update_account(
          bank_account.id,
          account: { institution_id: new_institution.id, bank_account_type: "savings" }
        )

        expect(response).to have_http_status(:ok)
        expect(bank_account.reload).to have_attributes(
          institution_id: new_institution.id,
          bank_account_type: "savings"
        )
      end

      it "allows updating a bank account whose current institution is inactive" do
        institution = create(:institution, :inactive, user:)
        bank_account = create(:account, :bank_account, user:, name: "Checking", institution:)

        update_account(bank_account.id, account: { name: "Still Checking" })

        expect(response).to have_http_status(:ok)
        expect(bank_account.reload).to have_attributes(
          name: "Still Checking",
          institution_id: institution.id
        )
      end

      it "rejects updating to an inactive institution" do
        bank_account = create(:account, :bank_account, user:, name: "Checking")
        inactive_institution = create(:institution, :inactive, user:, name: "Archive Bank")

        update_account(
          bank_account.id,
          account: { institution_id: inactive_institution.id }
        )

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "institution_id")).to eq([ "is inactive" ])
      end

      it "converts a cash account into a bank account" do
        institution = create(:institution, user:)

        update_account(
          account.id,
          account: {
            kind: "bank_account",
            institution_id: institution.id,
            bank_account_type: "checking"
          }
        )

        expect(response).to have_http_status(:ok)
        expect(account.reload).to have_attributes(
          kind: "bank_account",
          institution_id: institution.id,
          bank_account_type: "checking"
        )
      end

      it "converts a bank account into cash" do
        bank_account = create(:account, :bank_account, user:, name: "Checking")

        update_account(bank_account.id, account: { kind: "cash" })

        expect(response).to have_http_status(:ok)
        expect(bank_account.reload).to have_attributes(
          kind: "cash",
          institution_id: nil,
          bank_account_type: nil
        )
      end

      it "rejects an invalid color" do
        update_account(account.id, account: { color: "red" })

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "color")).to be_present
      end

      it "rejects a duplicate name for the same user" do
        create(:account, user:, name: "Cash")

        update_account(account.id, account: { name: "cash" })

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "name")).to be_present
      end

      it "returns 404 for another user's account" do
        update_account(create(:account).id, account: { name: "Hack" })

        expect(response).to have_http_status(:not_found)
      end
    end

    context "when unauthenticated" do
      subject { update_account(account.id, { account: { name: "Cash" } }, {}) }

      it_behaves_like "an unauthorized API request"
    end
  end

  describe "DELETE /api/v1/accounts/:id" do
    let!(:account) { create(:account, user:, name: "Wallet") }

    def destroy_account(id, request_headers = headers)
      delete "/api/v1/accounts/#{id}", headers: request_headers, as: :json
    end

    context "when authenticated" do
      it "deletes the account" do
        expect { destroy_account(account.id) }.to change(Account::Record, :count).by(-1)

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["message"]).to eq("Account deleted successfully")
      end

      it "returns 404 for another user's account" do
        destroy_account(create(:account).id)

        expect(response).to have_http_status(:not_found)
      end

      it "allows deactivating instead of deleting" do
        patch "/api/v1/accounts/#{account.id}", params: { account: { active: false } }, headers:, as: :json

        expect(response).to have_http_status(:ok)
        expect(account.reload.active).to be(false)
      end
    end

    context "when unauthenticated" do
      subject { destroy_account(account.id, {}) }

      it_behaves_like "an unauthorized API request"
    end
  end
end
