require "rails_helper"

RSpec.describe "API::V1::Categories", type: :request do
  let(:user) { create(:user, :verified) }
  let(:headers) { auth_headers_for(user) }

  def category_attributes(payload)
    payload.dig("data", "attributes")
  end

  describe "GET /api/v1/categories" do
    def list_categories(query = {}, request_headers = headers)
      get "/api/v1/categories", params: query, headers: request_headers
    end

    context "when authenticated" do
      let!(:active_category) { create(:category, user:, name: "Vacation", active: true) }
      let!(:inactive_category) { create(:category, :inactive, user:, name: "Archive") }
      let!(:other_user_category) { create(:category, name: "Other") }

      it "returns only the current user's categories" do
        list_categories

        ids = response.parsed_body["data"].map { |item| item.dig("attributes", "id") }

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["type"]).to eq("collection")
        expect(ids).to contain_exactly(active_category.id, inactive_category.id)
        expect(ids).not_to include(other_user_category.id)
      end

      it "orders by active desc, name asc by default" do
        list_categories

        names = response.parsed_body["data"].map { |item| item.dig("attributes", "name") }

        expect(names).to eq(%w[Vacation Archive])
      end

      it "filters by name and active" do
        list_categories(q: { name_cont: "Vac", active_eq: true })

        names = response.parsed_body["data"].map { |item| item.dig("attributes", "name") }

        expect(names).to eq(%w[Vacation])
      end

      it "paginates the collection" do
        list_categories(page: 1, per_page: 1)

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
        list_categories(q: { unknown_field_eq: "x" })

        ids = response.parsed_body["data"].map { |item| item.dig("attributes", "id") }

        expect(response).to have_http_status(:ok)
        expect(ids).to contain_exactly(active_category.id, inactive_category.id)
      end

      it "supports custom sorting" do
        list_categories(sort: "name asc")

        names = response.parsed_body["data"].map { |item| item.dig("attributes", "name") }

        expect(names).to eq(%w[Archive Vacation])
      end

      it "returns 422 for invalid pagination" do
        list_categories(page: 0)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "page")).to be_present
      end
    end

    context "when unauthenticated" do
      subject { list_categories({}, {}) }

      it_behaves_like "an unauthorized API request"
    end
  end

  describe "GET /api/v1/categories/:id" do
    let(:category) { create(:category, user:, name: "Vacation") }

    def show_category(id, request_headers = headers)
      get "/api/v1/categories/#{id}", headers: request_headers
    end

    context "when authenticated" do
      it "returns the category" do
        show_category(category.id)

        attributes = category_attributes(response.parsed_body)

        expect(response).to have_http_status(:ok)
        expect(attributes).to include(
          "id" => category.id,
          "name" => "Vacation",
          "color" => "#3B82F6",
          "active" => true
        )
      end

      it "returns 404 for another user's category" do
        show_category(create(:category).id)

        expect(response).to have_http_status(:not_found)
        expect(response.parsed_body["message"]).to eq("Category not found")
      end
    end

    context "when unauthenticated" do
      subject { show_category(category.id, {}) }

      it_behaves_like "an unauthorized API request"
    end
  end

  describe "POST /api/v1/categories" do
    def create_category(params, request_headers = headers)
      post "/api/v1/categories", params: params, headers: request_headers, as: :json
    end

    context "when authenticated" do
      it "creates a category" do
        expect {
          create_category(category: { name: "Vacation", color: "#3B82F6", active: true })
        }.to change(Category::Record, :count).by(1)

        attributes = category_attributes(response.parsed_body)

        expect(response).to have_http_status(:created)
        expect(response.parsed_body["message"]).to eq("Category created successfully")
        expect(attributes).to include(
          "name" => "Vacation",
          "color" => "#3B82F6",
          "active" => true
        )
      end

      it "defaults active to true" do
        create_category(category: { name: "Work", color: "#3B82F6" })

        expect(category_attributes(response.parsed_body)["active"]).to be(true)
      end

      it "strips the name" do
        create_category(category: { name: "  Vacation  ", color: "#3B82F6" })

        expect(category_attributes(response.parsed_body)["name"]).to eq("Vacation")
      end

      it "rejects a blank name" do
        create_category(category: { name: "", color: "#3B82F6" })

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "name")).to be_present
      end

      it "rejects a blank color" do
        create_category(category: { name: "Vacation", color: "" })

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "color")).to be_present
      end

      it "rejects an invalid color" do
        create_category(category: { name: "Vacation", color: "blue" })

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "color")).to be_present
      end

      it "rejects a duplicate name for the same user" do
        create(:category, user:, name: "Vacation")

        create_category(category: { name: "vacation", color: "#EF4444" })

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "name")).to be_present
      end

      it "returns 400 when the category param is missing" do
        create_category({})

        expect(response).to have_http_status(:bad_request)
      end
    end

    context "when unauthenticated" do
      subject { create_category({ category: { name: "Vacation", color: "#3B82F6" } }, {}) }

      it_behaves_like "an unauthorized API request"
    end
  end

  describe "PATCH /api/v1/categories/:id" do
    let(:category) { create(:category, user:, name: "Vacation", color: "#3B82F6", active: true) }

    def update_category(id, params, request_headers = headers)
      patch "/api/v1/categories/#{id}", params: params, headers: request_headers, as: :json
    end

    context "when authenticated" do
      it "updates the category" do
        update_category(category.id, category: { name: "Travel", color: "#10B981", active: false })

        attributes = category_attributes(response.parsed_body)

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["message"]).to eq("Category updated successfully")
        expect(attributes).to include(
          "name" => "Travel",
          "color" => "#10B981",
          "active" => false
        )
        expect(category.reload).to have_attributes(name: "Travel", color: "#10B981", active: false)
      end

      it "allows partial updates" do
        update_category(category.id, category: { active: false })

        expect(response).to have_http_status(:ok)
        expect(category.reload).to have_attributes(name: "Vacation", color: "#3B82F6", active: false)
      end

      it "rejects an invalid color" do
        update_category(category.id, category: { color: "red" })

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "color")).to be_present
      end

      it "rejects a duplicate name for the same user" do
        create(:category, user:, name: "Travel")

        update_category(category.id, category: { name: "travel" })

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "name")).to be_present
      end

      it "returns 404 for another user's category" do
        update_category(create(:category).id, category: { name: "Hack" })

        expect(response).to have_http_status(:not_found)
      end
    end

    context "when unauthenticated" do
      subject { update_category(category.id, { category: { name: "Travel" } }, {}) }

      it_behaves_like "an unauthorized API request"
    end
  end

  describe "DELETE /api/v1/categories/:id" do
    let!(:category) { create(:category, user:, name: "Vacation") }

    def destroy_category(id, request_headers = headers)
      delete "/api/v1/categories/#{id}", headers: request_headers, as: :json
    end

    context "when authenticated" do
      it "deletes the category" do
        expect { destroy_category(category.id) }.to change(Category::Record, :count).by(-1)

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["message"]).to eq("Category deleted successfully")
      end

      it "returns 404 for another user's category" do
        destroy_category(create(:category).id)

        expect(response).to have_http_status(:not_found)
      end

      it "allows deactivating instead of deleting" do
        patch "/api/v1/categories/#{category.id}", params: { category: { active: false } }, headers:, as: :json

        expect(response).to have_http_status(:ok)
        expect(category.reload.active).to be(false)
      end
    end

    context "when unauthenticated" do
      subject { destroy_category(category.id, {}) }

      it_behaves_like "an unauthorized API request"
    end
  end
end
