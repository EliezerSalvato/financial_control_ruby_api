require "rails_helper"

RSpec.describe Notification::Record, type: :model do
  include ActionCable::TestHelper

  let(:user) { create(:user, :verified) }

  describe "after_create_commit" do
    it "broadcasts when broadcast is true by default" do
      record = nil

      expect {
        record = create(:notification, user:, kind: "system", title: "Hello")
      }.to have_broadcasted_to(NotificationChannel.broadcasting_for(user.id)).with { |payload|
        expect(payload[:kind]).to eq("system")
        expect(payload[:unread_count]).to eq(1)
        expect(payload[:notification][:id]).to eq(record.id)
      }
    end

    it "does not broadcast when broadcast is false" do
      expect {
        create(:notification, :silent, user:)
      }.not_to have_broadcasted_to(NotificationChannel.broadcasting_for(user.id))
    end
  end

  describe "updates" do
    it "does not broadcast when read is updated" do
      record = create(:notification, :silent, user:)

      expect {
        record.update!(read: true, read_at: Time.current)
      }.not_to have_broadcasted_to(NotificationChannel.broadcasting_for(user.id))
    end
  end

  describe "boolean attributes" do
    it "exposes read and broadcast without conflicting with Active Record methods" do
      record = create(:notification, :silent, user:, read: false)

      expect(record.read).to be(false)
      expect(record.read?).to be(false)
      expect(record.broadcast).to be(false)
      expect(record.broadcast?).to be(false)

      record.update!(read: true, broadcast: true)

      expect(record.read).to be(true)
      expect(record.read?).to be(true)
      expect(record.broadcast).to be(true)
      expect(record.broadcast?).to be(true)
    end
  end
end
