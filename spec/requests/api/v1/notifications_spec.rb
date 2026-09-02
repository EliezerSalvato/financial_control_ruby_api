require "rails_helper"

RSpec.describe "API::V1::Notifications", type: :request do
  let(:user) { create(:user, :verified) }
  let(:headers) { auth_headers_for(user) }

  def notification_attributes(payload)
    payload.dig("data", "attributes")
  end

  describe "GET /api/v1/notifications" do
    def list_notifications(query = {}, request_headers = headers)
      get "/api/v1/notifications", params: query, headers: request_headers
    end

    context "when authenticated" do
      it "returns only the current user's notifications in id desc order" do
        older = create(:notification, user:, title: "Older")
        newer = create(:notification, user:, title: "Newer")
        other_user_notification = create(:notification, title: "Other")

        list_notifications

        ids = response.parsed_body["data"].map { |item| item.dig("attributes", "id") }

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["type"]).to eq("collection")
        expect(ids).to eq([ newer.id, older.id ])
        expect(ids).not_to include(other_user_notification.id)
      end

      it "respects the limit" do
        create_list(:notification, 3, user:)

        list_notifications(limit: 2)

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["data"].size).to eq(2)
        expect(response.parsed_body.dig("meta", "limit")).to eq(2)
      end

      it "paginates from the first page to the next via meta.next_cursor without repeating or skipping records" do
        first = create(:notification, user:, title: "First")
        second = create(:notification, user:, title: "Second")
        third = create(:notification, user:, title: "Third")

        list_notifications(limit: 2)

        first_page_ids = response.parsed_body["data"].map { |item| item.dig("attributes", "id") }
        meta = response.parsed_body["meta"]

        expect(first_page_ids).to eq([ third.id, second.id ])
        expect(meta).to include("has_more" => true, "limit" => 2)
        expect(meta["next_cursor"]).to be_present

        list_notifications(limit: 2, after: meta["next_cursor"])

        second_page_ids = response.parsed_body["data"].map { |item| item.dig("attributes", "id") }
        second_meta = response.parsed_body["meta"]

        expect(second_page_ids).to eq([ first.id ])
        expect(second_page_ids & first_page_ids).to be_empty
        expect(second_meta).to include("has_more" => false, "next_cursor" => nil)
      end

      it "returns has_more false and next_cursor null on the last page" do
        create(:notification, user:)

        list_notifications(limit: 10)

        expect(response.parsed_body["meta"]).to include(
          "has_more" => false,
          "next_cursor" => nil
        )
      end

      it "returns 400 for a corrupted cursor" do
        list_notifications(after: "not-a-valid-cursor")

        expect(response).to have_http_status(:bad_request)
        expect(response.parsed_body["message"]).to eq("Invalid cursor")
      end

      it "returns 422 when limit is above the ceiling" do
        list_notifications(limit: 101)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "limit")).to be_present
      end

      it "exposes unread_count in meta" do
        create(:notification, user:)
        create(:notification, :read, user:)
        create(:notification)

        list_notifications

        expect(response.parsed_body.dig("meta", "unread_count")).to eq(1)
      end

      it "filters to unread notifications when unread is true" do
        unread = create(:notification, user:, title: "Unread")
        create(:notification, :read, user:, title: "Read")

        list_notifications(unread: true)

        ids = response.parsed_body["data"].map { |item| item.dig("attributes", "id") }

        expect(response).to have_http_status(:ok)
        expect(ids).to eq([ unread.id ])
        expect(response.parsed_body.dig("meta", "unread_count")).to eq(1)
      end
    end

    context "when unauthenticated" do
      subject { list_notifications({}, {}) }

      it_behaves_like "an unauthorized API request"
    end
  end

  describe "GET /api/v1/notifications/:id" do
    let(:notification) { create(:notification, user:, title: "Invoice due") }

    def show_notification(id, request_headers = headers)
      get "/api/v1/notifications/#{id}", headers: request_headers
    end

    context "when authenticated" do
      it "returns the notification" do
        show_notification(notification.id)

        attributes = notification_attributes(response.parsed_body)

        expect(response).to have_http_status(:ok)
        expect(attributes).to include(
          "id" => notification.id,
          "kind" => "system",
          "title" => "Invoice due",
          "read" => false
        )
        expect(attributes).not_to have_key("broadcast")
      end

      it "returns 404 for another user's notification" do
        show_notification(create(:notification).id)

        expect(response).to have_http_status(:not_found)
        expect(response.parsed_body["message"]).to eq("Notification not found")
      end
    end

    context "when unauthenticated" do
      subject { show_notification(notification.id, {}) }

      it_behaves_like "an unauthorized API request"
    end
  end

  describe "POST /api/v1/notifications/:id/read" do
    let(:notification) { create(:notification, user:) }

    def read_notification(id, request_headers = headers)
      post "/api/v1/notifications/#{id}/read", headers: request_headers, as: :json
    end

    context "when authenticated" do
      it "marks the notification as read" do
        read_notification(notification.id)

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["message"]).to eq("Notification marked as read")
        expect(notification_attributes(response.parsed_body)).to include(
          "id" => notification.id,
          "read" => true
        )
        expect(notification.reload).to have_attributes(read: true)
        expect(notification.read_at).to be_present
      end

      it "is idempotent and preserves the original read_at" do
        original_read_at = 2.days.ago.change(usec: 0)
        notification.update!(read: true, read_at: original_read_at)

        read_notification(notification.id)

        expect(response).to have_http_status(:ok)
        expect(notification.reload.read_at).to eq(original_read_at)
      end

      it "returns 404 for another user's notification" do
        read_notification(create(:notification).id)

        expect(response).to have_http_status(:not_found)
        expect(response.parsed_body["message"]).to eq("Notification not found")
      end
    end

    context "when unauthenticated" do
      subject { read_notification(notification.id, {}) }

      it_behaves_like "an unauthorized API request"
    end
  end

  describe "POST /api/v1/notifications/read_all" do
    def read_all_notifications(request_headers = headers)
      post "/api/v1/notifications/read_all", headers: request_headers, as: :json
    end

    context "when authenticated" do
      it "marks all unread notifications as read and returns the count" do
        create(:notification, user:)
        create(:notification, user:)
        create(:notification, :read, user:)
        other_user_notification = create(:notification)

        read_all_notifications

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["message"]).to eq("Notifications marked as read")
        expect(response.parsed_body.dig("meta", "count")).to eq(2)
        expect(Notification::Record.where(user:, read: false).count).to eq(0)
        expect(other_user_notification.reload.read).to be(false)
      end

      it "succeeds with count zero when there is nothing to mark" do
        read_all_notifications

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body.dig("meta", "count")).to eq(0)
      end

      it "does not collide with the show route" do
        read_all_notifications

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["status"]).to eq("success")
      end
    end

    context "when unauthenticated" do
      subject { read_all_notifications({}) }

      it_behaves_like "an unauthorized API request"
    end
  end
end
