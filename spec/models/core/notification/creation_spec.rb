require "rails_helper"

RSpec.describe Core::Notification::Creation do
  include ActionCable::TestHelper

  let(:user) { create(:user, :verified) }

  def create_notification(**overrides)
    described_class.call(
      user_id: user.id,
      kind: "system",
      title: "Hello",
      **overrides
    )
  end

  it "creates a notification" do
    result = nil

    expect {
      result = create_notification
    }.to change(Notification::Record, :count).by(1)

    expect(result).to be_a(Solid::Success)
    expect(result.value[:notification]).to have_attributes(
      user_id: user.id,
      kind: "system",
      title: "Hello",
      read: false,
      data: {}
    )
  end

  it "defaults data to an empty hash" do
    result = create_notification

    expect(result.value[:notification].data).to eq({})
  end

  it "requires user_id, kind, and title" do
    result = described_class.call({})

    expect(result).to be_a(Solid::Failure)
    expect(result.value[:input].errors[:user_id]).to be_present
    expect(result.value[:input].errors[:kind]).to be_present
    expect(result.value[:input].errors[:title]).to be_present
  end

  it "rejects an incomplete notifiable pair" do
    result = create_notification(notifiable_type: "Transaction")

    expect(result).to be_a(Solid::Failure)
    expect(result.value[:input].errors[:notifiable_id]).to be_present
    expect(Notification::Record.count).to eq(0)
  end

  it "rejects notifiable_id without notifiable_type" do
    result = create_notification(notifiable_id: UUID.generate)

    expect(result).to be_a(Solid::Failure)
    expect(result.value[:input].errors[:notifiable_type]).to be_present
  end

  it "emits one individual event by default" do
    expect {
      create_notification(kind: "credit_card_invoice_due")
    }.to have_broadcasted_to(NotificationChannel.broadcasting_for(user.id)).exactly(:once)
  end

  it "does not emit an event when broadcast is false" do
    expect {
      create_notification(broadcast: false)
    }.not_to have_broadcasted_to(NotificationChannel.broadcasting_for(user.id))
  end

  describe "dedup_keys" do
    let(:transaction_id) { UUID.generate }
    let(:data) { { "month" => 8, "year" => 2026, "occurred_on" => Date.new(2026, 8, 11) } }

    def create_with_dedup(**overrides)
      create_notification(
        kind: "transaction.validation.errors",
        notifiable_type: "Transaction::Record",
        notifiable_id: transaction_id,
        data:,
        dedup_keys: %w[month year occurred_on],
        **overrides
      )
    end

    it "creates the first unread notification" do
      result = nil

      expect { result = create_with_dedup }.to change(Notification::Record, :count).by(1)

      expect(result).to be_a(Solid::Success)
      expect(result.value[:notification]).to have_attributes(kind: "transaction.validation.errors")
      expect(Notification::Record.find(result.value[:notification].id).dedup_key).to eq(
        "month" => 8,
        "year" => 2026,
        "occurred_on" => "2026-08-11"
      )
    end

    it "skips when an unread notification already exists for the same kind, notifiable, and keys" do
      create_with_dedup
      result = nil

      expect { result = create_with_dedup(title: "Duplicate") }.to change(Notification::Record, :count).by(0)

      expect(result).to be_a(Solid::Success)
      expect(result.type).to eq(:notification_skipped)
    end

    it "skips when a concurrent insert wins the unique unread index" do
      create_with_dedup
      allow(Notification::Repository::Adapters::ActiveRecord).to receive(:exists_unread?).and_return(false)

      result = nil

      expect { result = create_with_dedup(title: "Race") }.to change(Notification::Record, :count).by(0)

      expect(result).to be_a(Solid::Success)
      expect(result.type).to eq(:notification_skipped)
    end

    it "creates again when the previous notification has been read" do
      first = create_with_dedup
      Notification::Record.find(first.value[:notification].id).update!(read: true, read_at: Time.current)

      expect { create_with_dedup(title: "After read") }.to change(Notification::Record, :count).by(1)
    end

    it "rejects dedup_keys that are missing from data" do
      result = create_with_dedup(dedup_keys: %w[mont year])

      expect(result).to be_a(Solid::Failure)
      expect(result.type).to eq(:invalid_input)
      expect(result.value[:input].errors[:dedup_keys]).to be_present
      expect(Notification::Record.count).to eq(0)
    end
  end
end
