require "rails_helper"

RSpec.describe "API::V1::Institutions", type: :request do
  let(:user) { create(:user, :verified) }
  let(:headers) { auth_headers_for(user) }

  def institution_attributes(payload)
    payload.dig("data", "attributes")
  end

  describe "GET /api/v1/institutions" do
    def list_institutions(query = {}, request_headers = headers)
      get "/api/v1/institutions", params: query, headers: request_headers
    end

    context "when authenticated" do
      let!(:active_institution) { create(:institution, user:, name: "Nubank", active: true) }
      let!(:inactive_institution) { create(:institution, :inactive, user:, name: "Archive Bank") }
      let!(:other_user_institution) { create(:institution, name: "Other") }

      it "returns only the current user's institutions" do
        list_institutions

        ids = response.parsed_body["data"].map { |item| item.dig("attributes", "id") }

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["type"]).to eq("collection")
        expect(ids).to contain_exactly(active_institution.id, inactive_institution.id)
        expect(ids).not_to include(other_user_institution.id)
      end

      it "orders by active desc, name asc by default" do
        list_institutions

        names = response.parsed_body["data"].map { |item| item.dig("attributes", "name") }

        expect(names).to eq([ "Nubank", "Archive Bank" ])
      end

      it "filters by name and active" do
        list_institutions(q: { name_cont: "Nu", active_eq: true })

        names = response.parsed_body["data"].map { |item| item.dig("attributes", "name") }

        expect(names).to eq(%w[Nubank])
      end

      it "paginates the collection" do
        list_institutions(page: 1, per_page: 1)

        meta = response.parsed_body["meta"]

        expect(response.parsed_body["data"].size).to eq(1)
        expect(meta).to include(
          "page" => 1,
          "per_page" => 1,
          "count" => 2,
          "pages" => 2
        )
      end

      it "ignores unknown filters" do
        list_institutions(q: { unknown_field_eq: "x" })

        ids = response.parsed_body["data"].map { |item| item.dig("attributes", "id") }

        expect(response).to have_http_status(:ok)
        expect(ids).to contain_exactly(active_institution.id, inactive_institution.id)
      end

      it "supports custom sorting" do
        list_institutions(sort: "name asc")

        names = response.parsed_body["data"].map { |item| item.dig("attributes", "name") }

        expect(names).to eq([ "Archive Bank", "Nubank" ])
      end

      it "returns 422 for invalid pagination" do
        list_institutions(page: 0)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "page")).to be_present
      end
    end

    context "when unauthenticated" do
      subject { list_institutions({}, {}) }

      it_behaves_like "an unauthorized API request"
    end
  end

  describe "GET /api/v1/institutions/:id" do
    let(:institution) { create(:institution, user:, name: "Nubank", logo_key: "institutions/nubank.png") }

    def show_institution(id, request_headers = headers)
      get "/api/v1/institutions/#{id}", headers: request_headers
    end

    context "when authenticated" do
      it "returns the institution" do
        show_institution(institution.id)

        attributes = institution_attributes(response.parsed_body)

        expect(response).to have_http_status(:ok)
        expect(attributes).to include(
          "id" => institution.id,
          "name" => "Nubank",
          "logo_key" => "institutions/nubank.png",
          "active" => true
        )
      end

      it "returns 404 for another user's institution" do
        show_institution(create(:institution).id)

        expect(response).to have_http_status(:not_found)
        expect(response.parsed_body["message"]).to eq("Institution not found")
      end
    end

    context "when unauthenticated" do
      subject { show_institution(institution.id, {}) }

      it_behaves_like "an unauthorized API request"
    end
  end

  describe "POST /api/v1/institutions" do
    def create_institution(params, request_headers = headers)
      post "/api/v1/institutions", params: params, headers: request_headers, as: :json
    end

    context "when authenticated" do
      it "creates an institution" do
        expect {
          create_institution(institution: { name: "Nubank", logo_key: "institutions/nubank.png", active: true })
        }.to change(Institution::Record, :count).by(1)

        attributes = institution_attributes(response.parsed_body)

        expect(response).to have_http_status(:created)
        expect(response.parsed_body["message"]).to eq("Institution created successfully")
        expect(attributes).to include(
          "name" => "Nubank",
          "logo_key" => "institutions/nubank.png",
          "active" => true
        )
      end

      it "defaults active to true" do
        create_institution(institution: { name: "Inter", logo_key: "institutions/inter.png" })

        expect(institution_attributes(response.parsed_body)["active"]).to be(true)
      end

      it "rejects a blank logo_key" do
        create_institution(institution: { name: "Inter", logo_key: "" })

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "logo_key")).to be_present
      end

      it "strips the name" do
        create_institution(institution: { name: "  Nubank  ", logo_key: "institutions/nubank.png" })

        expect(institution_attributes(response.parsed_body)["name"]).to eq("Nubank")
      end

      it "rejects a blank name" do
        create_institution(institution: { name: "", logo_key: "institutions/nubank.png" })

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "name")).to be_present
      end

      it "rejects a duplicate name for the same user" do
        create(:institution, user:, name: "Nubank")

        create_institution(institution: { name: "nubank", logo_key: "institutions/other.png" })

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "name")).to be_present
      end

      it "returns 400 when the institution param is missing" do
        create_institution({})

        expect(response).to have_http_status(:bad_request)
      end
    end

    context "when unauthenticated" do
      subject { create_institution({ institution: { name: "Nubank" } }, {}) }

      it_behaves_like "an unauthorized API request"
    end
  end

  describe "PATCH /api/v1/institutions/:id" do
    let(:institution) do
      create(:institution, user:, name: "Nubank", logo_key: "institutions/nubank.png", active: true)
    end

    def update_institution(id, params, request_headers = headers)
      patch "/api/v1/institutions/#{id}", params: params, headers: request_headers, as: :json
    end

    context "when authenticated" do
      it "updates the institution" do
        update_institution(
          institution.id,
          institution: { name: "Inter", logo_key: "institutions/inter.png", active: false }
        )

        attributes = institution_attributes(response.parsed_body)

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["message"]).to eq("Institution updated successfully")
        expect(attributes).to include(
          "name" => "Inter",
          "logo_key" => "institutions/inter.png",
          "active" => false
        )
        expect(institution.reload).to have_attributes(
          name: "Inter",
          logo_key: "institutions/inter.png",
          active: false
        )
      end

      it "allows partial updates" do
        update_institution(institution.id, institution: { active: false })

        expect(response).to have_http_status(:ok)
        expect(institution.reload).to have_attributes(
          name: "Nubank",
          logo_key: "institutions/nubank.png",
          active: false
        )
      end

      it "rejects a duplicate name for the same user" do
        create(:institution, user:, name: "Inter")

        update_institution(institution.id, institution: { name: "inter" })

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "name")).to be_present
      end

      it "returns 404 for another user's institution" do
        update_institution(create(:institution).id, institution: { name: "Hack" })

        expect(response).to have_http_status(:not_found)
      end
    end

    context "when unauthenticated" do
      subject { update_institution(institution.id, { institution: { name: "Inter" } }, {}) }

      it_behaves_like "an unauthorized API request"
    end
  end

  describe "DELETE /api/v1/institutions/:id" do
    let!(:institution) { create(:institution, user:, name: "Nubank") }

    def destroy_institution(id, request_headers = headers)
      delete "/api/v1/institutions/#{id}", headers: request_headers, as: :json
    end

    context "when authenticated" do
      let(:used_by_transactions_message) do
        "This institution cannot be deleted because it has accounts or credit cards already used by transactions. To stop using it, inactivate the institution."
      end

      it "deletes the institution" do
        expect { destroy_institution(institution.id) }.to change(Institution::Record, :count).by(-1)

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["message"]).to eq("Institution deleted successfully")
      end

      it "deletes linked accounts and credit cards without transactions" do
        account = create(:account, :bank_account, user:, institution:)
        create(:credit_card, user:, institution:, default_payment_account: account)

        expect { destroy_institution(institution.id) }
          .to change(Institution::Record, :count).by(-1)
          .and change(Account::Record, :count).by(-1)
          .and change(CreditCard::Record, :count).by(-1)

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["message"]).to eq("Institution deleted successfully")
      end

      it "does not delete an institution whose accounts are used by transactions" do
        account = create(:account, :bank_account, user:, institution:)
        create(:transaction, user:, account:)

        expect { destroy_institution(institution.id) }.not_to change(Institution::Record, :count)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body["message"]).to eq(used_by_transactions_message)
        expect(response.parsed_body.dig("details", "base")).to eq([ used_by_transactions_message ])
        expect(account.reload).to be_present
      end

      it "does not delete an institution whose credit cards are used by transactions" do
        account = create(:account, :bank_account, user:, institution:)
        credit_card = create(:credit_card, user:, institution:, default_payment_account: account)
        create(:transaction, :with_credit_card, user:, credit_card:)

        expect { destroy_institution(institution.id) }.not_to change(Institution::Record, :count)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body["message"]).to eq(used_by_transactions_message)
        expect(credit_card.reload).to be_present
      end

      it "does not delete accounts or credit cards of another institution" do
        other_institution = create(:institution, user:, name: "Other Bank")
        other_account = create(:account, :bank_account, user:, institution: other_institution)
        create(:credit_card, user:, institution: other_institution, default_payment_account: other_account)

        destroy_institution(institution.id)

        expect(response).to have_http_status(:ok)
        expect(Institution::Record.find_by(id: other_institution.id)).to be_present
        expect(Account::Record.find_by(id: other_account.id)).to be_present
      end

      it "returns 404 for another user's institution" do
        destroy_institution(create(:institution).id)

        expect(response).to have_http_status(:not_found)
      end

      it "allows deactivating instead of deleting" do
        patch "/api/v1/institutions/#{institution.id}", params: { institution: { active: false } }, headers:, as: :json

        expect(response).to have_http_status(:ok)
        expect(institution.reload.active).to be(false)
      end
    end

    context "when unauthenticated" do
      subject { destroy_institution(institution.id, {}) }

      it_behaves_like "an unauthorized API request"
    end
  end
end
