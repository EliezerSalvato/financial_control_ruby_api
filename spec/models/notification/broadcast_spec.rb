require "rails_helper"

RSpec.describe Notification::Broadcast do
  let(:user) { create(:user, :verified) }
  let(:notification) do
    Notification::Mapper.to_entity(
      create(:notification, :silent, user:, kind: "credit_card_invoice_due", title: "Invoice due")
    )
  end

  describe ".stream_target" do
    it "is the user id" do
      expect(described_class.stream_target(user.id)).to eq(user.id)
    end
  end

  describe ".created" do
    include ActionCable::TestHelper

    it "broadcasts the notification kind, resource, and unread_count" do
      create(:notification, :silent, user:)

      expect {
        described_class.created(notification)
      }.to have_broadcasted_to(NotificationChannel.broadcasting_for(user.id)).with { |payload|
        expect(payload[:kind]).to eq("credit_card_invoice_due")
        expect(payload[:unread_count]).to eq(2)
        expect(payload[:notification]).to include(
          id: notification.id,
          type: "notification"
        )
        expect(payload[:notification][:attributes]).to include(
          kind: "credit_card_invoice_due",
          title: "Invoice due"
        )
      }
    end
  end

  describe ".batch_created" do
    include ActionCable::TestHelper

    it "broadcasts the given kind and unread_count without a notification resource" do
      create(:notification, :silent, user:)

      expect {
        described_class.batch_created(user_id: user.id, kind: "daily_summary")
      }.to have_broadcasted_to(NotificationChannel.broadcasting_for(user.id)).with(
        kind: "daily_summary",
        unread_count: 1
      )
    end
  end
end
