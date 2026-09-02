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
    result = create_notification(notifiable_id: SecureRandom.uuid)

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
end
