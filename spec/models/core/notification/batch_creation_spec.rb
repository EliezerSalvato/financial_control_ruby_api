require "rails_helper"

RSpec.describe Core::Notification::BatchCreation do
  include ActionCable::TestHelper

  let(:user) { create(:user, :verified) }

  def create_all(notifications:, broadcast_kind: "daily_summary")
    described_class.call(user_id: user.id, notifications:, broadcast_kind:)
  end

  it "creates N notifications, emits no individual events, and emits one group event with broadcast_kind" do
    notifications = [
      { kind: "credit_card_invoice_due", title: "Invoice due" },
      { kind: "transaction_due", title: "Occurrence due" }
    ]

    result = nil

    expect {
      result = create_all(notifications:)
    }.to change(Notification::Record, :count).by(2)
      .and have_broadcasted_to(NotificationChannel.broadcasting_for(user.id)).exactly(:once)

    expect(result).to be_a(Solid::Success)
    expect(result.value[:notifications].size).to eq(2)
    expect(Notification::Record.where(user:, broadcast: false).count).to eq(2)
  end

  it "uses the given broadcast_kind and omits the notification resource" do
    expect {
      create_all(notifications: [ { kind: "system", title: "Hello" } ], broadcast_kind: "daily_summary")
    }.to have_broadcasted_to(NotificationChannel.broadcasting_for(user.id)).with { |payload|
      expect(payload[:kind]).to eq("daily_summary")
      expect(payload).not_to have_key(:notification)
      expect(payload[:unread_count]).to eq(1)
    }
  end

  it "reflects the total unread count after the batch in the payload" do
    create(:notification, :silent, user:)

    expect {
      create_all(notifications: [
        { kind: "system", title: "One" },
        { kind: "system", title: "Two" }
      ])
    }.to have_broadcasted_to(NotificationChannel.broadcasting_for(user.id)).with(
      kind: "daily_summary",
      unread_count: 3
    )
  end

  it "creates nothing and emits no event for an empty batch" do
    result = nil

    expect {
      result = create_all(notifications: [])
    }.to change(Notification::Record, :count).by(0)
      .and have_broadcasted_to(NotificationChannel.broadcasting_for(user.id)).exactly(0).times

    expect(result).to be_a(Solid::Success)
    expect(result.type).to eq(:no_notifications_created)
    expect(result.value[:notifications]).to eq([])
  end

  it "rolls back the whole batch and emits no event when an item is invalid" do
    result = nil

    expect {
      result = create_all(
        notifications: [
          { kind: "system", title: "Valid" },
          { kind: "system" }
        ]
      )
    }.to change(Notification::Record, :count).by(0)
      .and have_broadcasted_to(NotificationChannel.broadcasting_for(user.id)).exactly(0).times

    expect(result).to be_a(Solid::Failure)
  end

  it "skips duplicate unread items and still creates the others" do
    create(
      :notification,
      :silent,
      user:,
      kind: "transaction.validation.errors",
      notifiable_type: "Transaction::Record",
      notifiable_id: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
      data: { "month" => 8, "year" => 2026 }
    )
    result = nil

    expect {
      result = create_all(
        notifications: [
          {
            kind: "transaction.validation.errors",
            title: "Duplicate",
            notifiable_type: "Transaction::Record",
            notifiable_id: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
            data: { month: 8, year: 2026 },
            dedup_keys: %w[month year]
          },
          { kind: "system", title: "New" }
        ]
      )
    }.to change(Notification::Record, :count).by(1)

    expect(result).to be_a(Solid::Success)
    expect(result.value[:notifications].size).to eq(1)
    expect(result.value[:notifications].sole.title).to eq("New")
  end
end
