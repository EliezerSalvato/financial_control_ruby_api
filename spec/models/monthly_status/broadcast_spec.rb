require "rails_helper"

RSpec.describe MonthlyStatus::Broadcast do
  let(:user) { create(:user, :verified) }
  let(:monthly_status) do
    MonthlyStatus::Mapper.to_entity(
      create(:monthly_status, :processing, user:, month: 8, year: 2026, last_processed_at: processed_at)
    )
  end
  let(:processed_at) { Time.zone.parse("2026-08-30 14:00:00") }

  describe ".stream_target" do
    it "is scoped to the owner and calendar month" do
      expect(described_class.stream_target(monthly_status)).to eq([ user.id, 2026, 8 ])
    end
  end

  describe ".payload" do
    it "exposes processing and last_processed_at" do
      expect(described_class.payload(monthly_status)).to eq(
        processing: true,
        last_processed_at: processed_at.iso8601
      )
    end

    it "serializes a missing last_processed_at as nil" do
      monthly_status = MonthlyStatus::Mapper.to_entity(create(:monthly_status, user:))

      expect(described_class.payload(monthly_status)).to eq(processing: false, last_processed_at: nil)
    end
  end

  describe ".processing_changed" do
    include ActionCable::TestHelper

    it "broadcasts the payload to the monthly status stream" do
      expect {
        described_class.processing_changed(monthly_status)
      }.to have_broadcasted_to([ user.id, 2026, 8 ]).from_channel(MonthlyStatusChannel).with(
        processing: true,
        last_processed_at: processed_at.iso8601
      )
    end
  end
end
