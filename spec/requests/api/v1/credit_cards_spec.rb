require "rails_helper"

RSpec.describe "API::V1::CreditCards", type: :request do
  let(:user) { create(:user, :verified) }
  let(:headers) { auth_headers_for(user) }
  let(:institution) { create(:institution, user:) }
  let(:payment_account) { create(:account, :bank_account, user:, institution:) }

  def credit_card_attributes(payload)
    payload.dig("data", "attributes")
  end

  def create_params(overrides = {})
    {
      credit_card: {
        institution_id: institution.id,
        default_payment_account_id: payment_account.id,
        name: "Platinum",
        total_limit: 5000,
        available_limit: 5000,
        closing_day: 10,
        due_day: 17,
        network: "mastercard",
        active: true
      }.merge(overrides)
    }
  end

  describe "GET /api/v1/credit_cards" do
    def list_credit_cards(query = {}, request_headers = headers)
      get "/api/v1/credit_cards", params: query, headers: request_headers
    end

    context "when authenticated" do
      let!(:active_credit_card) do
        create(:credit_card, user:, institution:, default_payment_account: payment_account, name: "Platinum", active: true)
      end
      let!(:inactive_credit_card) do
        create(:credit_card, :inactive, user:, institution:, default_payment_account: payment_account, name: "Archive")
      end
      let!(:other_user_credit_card) { create(:credit_card, name: "Other") }

      it "returns only the current user's credit cards" do
        list_credit_cards

        ids = response.parsed_body["data"].map { |item| item.dig("attributes", "id") }

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["type"]).to eq("collection")
        expect(ids).to contain_exactly(active_credit_card.id, inactive_credit_card.id)
        expect(ids).not_to include(other_user_credit_card.id)
      end

      it "orders by active desc, name asc by default" do
        list_credit_cards

        names = response.parsed_body["data"].map { |item| item.dig("attributes", "name") }

        expect(names).to eq(%w[Platinum Archive])
      end

      it "filters by name and active" do
        list_credit_cards(q: { name_cont: "Plat", active_eq: true })

        names = response.parsed_body["data"].map { |item| item.dig("attributes", "name") }

        expect(names).to eq(%w[Platinum])
      end

      it "filters by allow_negative_available_limit" do
        create(:credit_card, :allow_negative_available_limit, user:, institution:, default_payment_account: payment_account, name: "Unlimited")

        list_credit_cards(q: { allow_negative_available_limit_eq: true })

        names = response.parsed_body["data"].map { |item| item.dig("attributes", "name") }

        expect(names).to eq(%w[Unlimited])
      end

      it "paginates the collection" do
        list_credit_cards(page: 1, per_page: 1)

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
        list_credit_cards(q: { unknown_field_eq: "x" })

        ids = response.parsed_body["data"].map { |item| item.dig("attributes", "id") }

        expect(response).to have_http_status(:ok)
        expect(ids).to contain_exactly(active_credit_card.id, inactive_credit_card.id)
      end

      it "supports custom sorting" do
        list_credit_cards(sort: "name asc")

        names = response.parsed_body["data"].map { |item| item.dig("attributes", "name") }

        expect(names).to eq(%w[Archive Platinum])
      end

      it "returns 422 for invalid pagination" do
        list_credit_cards(page: 0)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "page")).to be_present
      end
    end

    context "when unauthenticated" do
      subject { list_credit_cards({}, {}) }

      it_behaves_like "an unauthorized API request"
    end
  end

  describe "GET /api/v1/credit_cards/:id" do
    let(:credit_card) do
      create(:credit_card, user:, institution:, default_payment_account: payment_account, name: "Platinum")
    end

    def show_credit_card(id, request_headers = headers)
      get "/api/v1/credit_cards/#{id}", headers: request_headers
    end

    context "when authenticated" do
      it "returns the credit card" do
        show_credit_card(credit_card.id)

        attributes = credit_card_attributes(response.parsed_body)

        expect(response).to have_http_status(:ok)
        expect(attributes).to include(
          "id" => credit_card.id,
          "name" => "Platinum",
          "network" => "mastercard",
          "institution_id" => institution.id,
          "default_payment_account_id" => payment_account.id,
          "closing_day" => 10,
          "due_day" => 17,
          "allow_negative_available_limit" => false,
          "active" => true
        )
      end

      it "returns 404 for another user's credit card" do
        show_credit_card(create(:credit_card).id)

        expect(response).to have_http_status(:not_found)
        expect(response.parsed_body["message"]).to eq("Credit card not found")
      end
    end

    context "when unauthenticated" do
      subject { show_credit_card(credit_card.id, {}) }

      it_behaves_like "an unauthorized API request"
    end
  end

  describe "POST /api/v1/credit_cards" do
    def create_credit_card(params, request_headers = headers)
      post "/api/v1/credit_cards", params: params, headers: request_headers, as: :json
    end

    context "when authenticated" do
      it "creates a credit card" do
        expect {
          create_credit_card(create_params)
        }.to change(CreditCard::Record, :count).by(1)

        attributes = credit_card_attributes(response.parsed_body)

        expect(response).to have_http_status(:created)
        expect(response.parsed_body["message"]).to eq("Credit card created successfully")
        expect(attributes).to include(
          "name" => "Platinum",
          "network" => "mastercard",
          "institution_id" => institution.id,
          "default_payment_account_id" => payment_account.id,
          "allow_negative_available_limit" => false,
          "active" => true
        )
      end

      it "defaults active to true, allow_negative_available_limit to false, and limits to 0" do
        create_credit_card(
          create_params(
            total_limit: nil,
            available_limit: nil,
            active: nil
          ).tap { |params| params[:credit_card].except!(:total_limit, :available_limit, :active) }
        )

        attributes = credit_card_attributes(response.parsed_body)

        expect(response).to have_http_status(:created)
        expect(attributes["active"]).to be(true)
        expect(attributes["allow_negative_available_limit"]).to be(false)
        expect(attributes["total_limit"].to_d).to eq(0)
        expect(attributes["available_limit"].to_d).to eq(0)
      end

      it "creates with allow_negative_available_limit enabled" do
        create_credit_card(create_params(allow_negative_available_limit: true))

        expect(credit_card_attributes(response.parsed_body)["allow_negative_available_limit"]).to be(true)
      end

      it "strips the name" do
        create_credit_card(create_params(name: "  Platinum  "))

        expect(credit_card_attributes(response.parsed_body)["name"]).to eq("Platinum")
      end

      it "rejects a blank name" do
        create_credit_card(create_params(name: ""))

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "name")).to be_present
      end

      it "rejects an invalid closing day" do
        create_credit_card(create_params(closing_day: 32))

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "closing_day")).to be_present
      end

      it "sets available_limit equal to total_limit" do
        create_credit_card(create_params(total_limit: 1000, available_limit: 1500))

        attributes = credit_card_attributes(response.parsed_body)

        expect(response).to have_http_status(:created)
        expect(attributes["total_limit"].to_d).to eq(1000)
        expect(attributes["available_limit"].to_d).to eq(1000)
      end

      it "rejects a duplicate name for the same user" do
        create(:credit_card, user:, institution:, default_payment_account: payment_account, name: "Platinum")

        create_credit_card(create_params(name: "platinum"))

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "name")).to be_present
      end

      it "rejects another user's institution" do
        create_credit_card(create_params(institution_id: create(:institution).id))

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "institution_id")).to be_present
      end

      it "rejects an inactive institution" do
        inactive_institution = create(:institution, :inactive, user:)

        create_credit_card(create_params(institution_id: inactive_institution.id))

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "institution_id")).to eq([ "is inactive" ])
      end

      it "rejects another user's payment account" do
        create_credit_card(create_params(default_payment_account_id: create(:account, :bank_account).id))

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "default_payment_account_id")).to be_present
      end

      it "rejects an inactive payment account" do
        inactive_account = create(:account, :bank_account, :inactive, user:, institution:)

        create_credit_card(create_params(default_payment_account_id: inactive_account.id))

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "default_payment_account_id")).to eq([ "is inactive" ])
      end

      it "returns 400 when the credit_card param is missing" do
        create_credit_card({})

        expect(response).to have_http_status(:bad_request)
      end
    end

    context "when unauthenticated" do
      subject { create_credit_card(create_params, {}) }

      it_behaves_like "an unauthorized API request"
    end
  end

  describe "PATCH /api/v1/credit_cards/:id" do
    let(:credit_card) do
      create(
        :credit_card,
        user:,
        institution:,
        default_payment_account: payment_account,
        name: "Platinum",
        total_limit: 5000,
        available_limit: 5000,
        active: true
      )
    end

    def update_credit_card(id, params, request_headers = headers)
      patch "/api/v1/credit_cards/#{id}", params: params, headers: request_headers, as: :json
    end

    context "when authenticated" do
      it "updates the credit card" do
        update_credit_card(
          credit_card.id,
          credit_card: { name: "Ultravioleta", active: false }
        )

        attributes = credit_card_attributes(response.parsed_body)

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["message"]).to eq("Credit card updated successfully")
        expect(attributes).to include(
          "name" => "Ultravioleta",
          "active" => false
        )
        expect(credit_card.reload).to have_attributes(name: "Ultravioleta", available_limit: 5000, active: false)
      end

      it "updates allow_negative_available_limit" do
        update_credit_card(credit_card.id, credit_card: { allow_negative_available_limit: true })

        expect(response).to have_http_status(:ok)
        expect(credit_card_attributes(response.parsed_body)["allow_negative_available_limit"]).to be(true)
        expect(credit_card.reload.allow_negative_available_limit).to be(true)
      end

      it "allows partial updates" do
        update_credit_card(credit_card.id, credit_card: { active: false })

        expect(response).to have_http_status(:ok)
        expect(credit_card.reload).to have_attributes(name: "Platinum", active: false)
      end

      it "increases available_limit when total_limit increases" do
        credit_card.update!(available_limit: 3000)

        update_credit_card(credit_card.id, credit_card: { total_limit: 7000 })

        attributes = credit_card_attributes(response.parsed_body)

        expect(response).to have_http_status(:ok)
        expect(attributes["total_limit"].to_d).to eq(7000)
        expect(attributes["available_limit"].to_d).to eq(5000)
        expect(credit_card.reload).to have_attributes(total_limit: 7000, available_limit: 5000)
      end

      it "decreases available_limit when total_limit decreases" do
        credit_card.update!(available_limit: 3000)

        update_credit_card(credit_card.id, credit_card: { total_limit: 4000 })

        attributes = credit_card_attributes(response.parsed_body)

        expect(response).to have_http_status(:ok)
        expect(attributes["total_limit"].to_d).to eq(4000)
        expect(attributes["available_limit"].to_d).to eq(2000)
        expect(credit_card.reload).to have_attributes(total_limit: 4000, available_limit: 2000)
      end

      it "rejects total_limit that would make available_limit negative" do
        credit_card.update!(available_limit: 1000)

        update_credit_card(credit_card.id, credit_card: { total_limit: 3000 })

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "total_limit")).to be_present
        expect(credit_card.reload).to have_attributes(total_limit: 5000, available_limit: 1000)
      end

      it "rejects a duplicate name for the same user" do
        create(:credit_card, user:, institution:, default_payment_account: payment_account, name: "Travel")

        update_credit_card(credit_card.id, credit_card: { name: "travel" })

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "name")).to be_present
      end

      it "allows updating a credit card whose current institution is inactive" do
        inactive_institution = create(:institution, :inactive, user:, name: "Archive Bank")
        credit_card.update!(institution: inactive_institution)

        update_credit_card(credit_card.id, credit_card: { name: "Still Valid" })

        expect(response).to have_http_status(:ok)
        expect(credit_card.reload).to have_attributes(name: "Still Valid", institution_id: inactive_institution.id)
      end

      it "rejects updating to an inactive institution" do
        inactive_institution = create(:institution, :inactive, user:, name: "Archive Bank")

        update_credit_card(credit_card.id, credit_card: { institution_id: inactive_institution.id })

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "institution_id")).to eq([ "is inactive" ])
      end

      it "rejects updating to an inactive payment account" do
        inactive_account = create(:account, :bank_account, :inactive, user:, institution:, name: "Archive Account")

        update_credit_card(credit_card.id, credit_card: { default_payment_account_id: inactive_account.id })

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "default_payment_account_id")).to eq([ "is inactive" ])
      end

      it "returns 404 for another user's credit card" do
        update_credit_card(create(:credit_card).id, credit_card: { name: "Hack" })

        expect(response).to have_http_status(:not_found)
      end
    end

    context "when unauthenticated" do
      subject { update_credit_card(credit_card.id, { credit_card: { name: "Travel" } }, {}) }

      it_behaves_like "an unauthorized API request"
    end
  end

  describe "DELETE /api/v1/credit_cards/:id" do
    let!(:credit_card) do
      create(:credit_card, user:, institution:, default_payment_account: payment_account, name: "Platinum")
    end

    def destroy_credit_card(id, request_headers = headers)
      delete "/api/v1/credit_cards/#{id}", headers: request_headers, as: :json
    end

    context "when authenticated" do
      it "deletes the credit card" do
        expect { destroy_credit_card(credit_card.id) }.to change(CreditCard::Record, :count).by(-1)

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["message"]).to eq("Credit card deleted successfully")
      end

      it "returns 404 for another user's credit card" do
        destroy_credit_card(create(:credit_card).id)

        expect(response).to have_http_status(:not_found)
      end

      it "allows deactivating instead of deleting" do
        patch "/api/v1/credit_cards/#{credit_card.id}", params: { credit_card: { active: false } }, headers:, as: :json

        expect(response).to have_http_status(:ok)
        expect(credit_card.reload.active).to be(false)
      end
    end

    context "when unauthenticated" do
      subject { destroy_credit_card(credit_card.id, {}) }

      it_behaves_like "an unauthorized API request"
    end
  end
end
