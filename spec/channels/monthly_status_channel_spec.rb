require "rails_helper"

RSpec.describe MonthlyStatusChannel, type: :channel do
  let(:user) { create(:user, :verified) }
  let(:user_entity) { User::Mapper.to_entity(user) }

  before { stub_connection(current_user: user_entity) }

  it "streams the monthly status and transmits the current processing payload" do
    processed_at = Time.zone.parse("2026-08-30 14:00:00")
    create(:monthly_status, :processing, user:, month: 8, year: 2026, last_processed_at: processed_at)

    subscribe(month: 8, year: 2026)

    expect(subscription).to be_confirmed
    expect(subscription).to have_stream_for([ user.id, 2026, 8 ])
    expect(transmissions.last).to eq(
      "processing" => true,
      "last_processed_at" => processed_at.iso8601
    )
  end

  it "rejects when the monthly status does not exist" do
    subscribe(month: 8, year: 2026)

    expect(subscription).to be_rejected
  end

  it "rejects another user's monthly status" do
    other_user = create(:user, :verified)
    create(:monthly_status, user: other_user, month: 8, year: 2026)

    subscribe(month: 8, year: 2026)

    expect(subscription).to be_rejected
  end

  it "rejects invalid month and year" do
    subscribe(month: 13, year: 0)

    expect(subscription).to be_rejected
  end
end
