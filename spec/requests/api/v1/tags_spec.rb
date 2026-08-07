require "rails_helper"

RSpec.describe "API::V1::Tags", type: :request do
  let(:user) { create(:user, :verified) }
  let(:headers) { auth_headers_for(user) }

  def tag_attributes(payload)
    payload.dig("data", "attributes")
  end

  describe "GET /api/v1/tags" do
    def list_tags(query = {}, request_headers = headers)
      get "/api/v1/tags", params: query, headers: request_headers
    end

    context "when authenticated" do
      let!(:active_tag) { create(:tag, user:, name: "Vacation", active: true) }
      let!(:inactive_tag) { create(:tag, :inactive, user:, name: "Archive") }
      let!(:other_user_tag) { create(:tag, name: "Other") }

      it "returns only the current user's tags" do
        list_tags

        ids = response.parsed_body["data"].map { |item| item.dig("attributes", "id") }

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["type"]).to eq("collection")
        expect(ids).to contain_exactly(active_tag.id, inactive_tag.id)
        expect(ids).not_to include(other_user_tag.id)
      end

      it "orders by active desc, name asc by default" do
        list_tags

        names = response.parsed_body["data"].map { |item| item.dig("attributes", "name") }

        expect(names).to eq(%w[Vacation Archive])
      end

      it "filters by name and active" do
        list_tags(q: { name_cont: "Vac", active_eq: true })

        names = response.parsed_body["data"].map { |item| item.dig("attributes", "name") }

        expect(names).to eq(%w[Vacation])
      end

      it "paginates the collection" do
        list_tags(page: 1, per_page: 1)

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
        list_tags(q: { unknown_field_eq: "x" })

        ids = response.parsed_body["data"].map { |item| item.dig("attributes", "id") }

        expect(response).to have_http_status(:ok)
        expect(ids).to contain_exactly(active_tag.id, inactive_tag.id)
      end

      it "supports custom sorting" do
        list_tags(sort: "name asc")

        names = response.parsed_body["data"].map { |item| item.dig("attributes", "name") }

        expect(names).to eq(%w[Archive Vacation])
      end

      it "returns 422 for invalid pagination" do
        list_tags(page: 0)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "page")).to be_present
      end
    end

    context "when unauthenticated" do
      subject { list_tags({}, {}) }

      it_behaves_like "an unauthorized API request"
    end
  end

  describe "GET /api/v1/tags/:id" do
    let(:tag) { create(:tag, user:, name: "Vacation") }

    def show_tag(id, request_headers = headers)
      get "/api/v1/tags/#{id}", headers: request_headers
    end

    context "when authenticated" do
      it "returns the tag" do
        show_tag(tag.id)

        attributes = tag_attributes(response.parsed_body)

        expect(response).to have_http_status(:ok)
        expect(attributes).to include(
          "id" => tag.id,
          "name" => "Vacation",
          "color" => "#3B82F6",
          "active" => true
        )
      end

      it "returns 404 for another user's tag" do
        show_tag(create(:tag).id)

        expect(response).to have_http_status(:not_found)
        expect(response.parsed_body["message"]).to eq("Tag not found")
      end
    end

    context "when unauthenticated" do
      subject { show_tag(tag.id, {}) }

      it_behaves_like "an unauthorized API request"
    end
  end

  describe "POST /api/v1/tags" do
    def create_tag(params, request_headers = headers)
      post "/api/v1/tags", params: params, headers: request_headers, as: :json
    end

    context "when authenticated" do
      it "creates a tag" do
        expect {
          create_tag(tag: { name: "Vacation", color: "#3B82F6", active: true })
        }.to change(Tag::Record, :count).by(1)

        attributes = tag_attributes(response.parsed_body)

        expect(response).to have_http_status(:created)
        expect(response.parsed_body["message"]).to eq("Tag created successfully")
        expect(attributes).to include(
          "name" => "Vacation",
          "color" => "#3B82F6",
          "active" => true
        )
      end

      it "defaults active to true" do
        create_tag(tag: { name: "Work", color: "#3B82F6" })

        expect(tag_attributes(response.parsed_body)["active"]).to be(true)
      end

      it "strips the name" do
        create_tag(tag: { name: "  Vacation  ", color: "#3B82F6" })

        expect(tag_attributes(response.parsed_body)["name"]).to eq("Vacation")
      end

      it "rejects a blank name" do
        create_tag(tag: { name: "", color: "#3B82F6" })

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "name")).to be_present
      end

      it "rejects a blank color" do
        create_tag(tag: { name: "Vacation", color: "" })

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "color")).to be_present
      end

      it "rejects an invalid color" do
        create_tag(tag: { name: "Vacation", color: "blue" })

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "color")).to be_present
      end

      it "rejects a duplicate name for the same user" do
        create(:tag, user:, name: "Vacation")

        create_tag(tag: { name: "vacation", color: "#EF4444" })

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "name")).to be_present
      end

      it "returns 400 when the tag param is missing" do
        create_tag({})

        expect(response).to have_http_status(:bad_request)
      end
    end

    context "when unauthenticated" do
      subject { create_tag({ tag: { name: "Vacation", color: "#3B82F6" } }, {}) }

      it_behaves_like "an unauthorized API request"
    end
  end

  describe "PATCH /api/v1/tags/:id" do
    let(:tag) { create(:tag, user:, name: "Vacation", color: "#3B82F6", active: true) }

    def update_tag(id, params, request_headers = headers)
      patch "/api/v1/tags/#{id}", params: params, headers: request_headers, as: :json
    end

    context "when authenticated" do
      it "updates the tag" do
        update_tag(tag.id, tag: { name: "Travel", color: "#10B981", active: false })

        attributes = tag_attributes(response.parsed_body)

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["message"]).to eq("Tag updated successfully")
        expect(attributes).to include(
          "name" => "Travel",
          "color" => "#10B981",
          "active" => false
        )
        expect(tag.reload).to have_attributes(name: "Travel", color: "#10B981", active: false)
      end

      it "allows partial updates" do
        update_tag(tag.id, tag: { active: false })

        expect(response).to have_http_status(:ok)
        expect(tag.reload).to have_attributes(name: "Vacation", color: "#3B82F6", active: false)
      end

      it "rejects an invalid color" do
        update_tag(tag.id, tag: { color: "red" })

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "color")).to be_present
      end

      it "rejects a duplicate name for the same user" do
        create(:tag, user:, name: "Travel")

        update_tag(tag.id, tag: { name: "travel" })

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "name")).to be_present
      end

      it "returns 404 for another user's tag" do
        update_tag(create(:tag).id, tag: { name: "Hack" })

        expect(response).to have_http_status(:not_found)
      end
    end

    context "when unauthenticated" do
      subject { update_tag(tag.id, { tag: { name: "Travel" } }, {}) }

      it_behaves_like "an unauthorized API request"
    end
  end

  describe "DELETE /api/v1/tags/:id" do
    let!(:tag) { create(:tag, user:, name: "Vacation") }

    def destroy_tag(id, request_headers = headers)
      delete "/api/v1/tags/#{id}", headers: request_headers, as: :json
    end

    context "when authenticated" do
      it "deletes the tag" do
        expect { destroy_tag(tag.id) }.to change(Tag::Record, :count).by(-1)

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["message"]).to eq("Tag deleted successfully")
      end

      it "returns 404 for another user's tag" do
        destroy_tag(create(:tag).id)

        expect(response).to have_http_status(:not_found)
      end

      it "allows deactivating instead of deleting" do
        patch "/api/v1/tags/#{tag.id}", params: { tag: { active: false } }, headers:, as: :json

        expect(response).to have_http_status(:ok)
        expect(tag.reload.active).to be(false)
      end
    end

    context "when unauthenticated" do
      subject { destroy_tag(tag.id, {}) }

      it_behaves_like "an unauthorized API request"
    end
  end
end
