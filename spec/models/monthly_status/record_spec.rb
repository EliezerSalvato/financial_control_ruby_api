require "rails_helper"

RSpec.describe MonthlyStatus::Record, type: :model do
  include ActionCable::TestHelper

  let(:user) { create(:user, :verified) }

  describe "after_update_commit" do
    it "broadcasts when processing becomes true" do
      record = create(:monthly_status, user:, month: 8, year: 2026)

      expect {
        record.update!(processing: true)
      }.to have_broadcasted_to([ user.id, 2026, 8 ]).from_channel(MonthlyStatusChannel).with(
        processing: true,
        last_processed_at: nil
      )
    end

    it "broadcasts when processing becomes false" do
      record = create(:monthly_status, :processing, user:, month: 8, year: 2026)
      processed_at = Time.zone.parse("2026-08-30 14:00:00")

      expect {
        record.update!(processing: false, last_processed_at: processed_at)
      }.to have_broadcasted_to([ user.id, 2026, 8 ]).from_channel(MonthlyStatusChannel).with(
        processing: false,
        last_processed_at: processed_at.iso8601
      )
    end

    it "does not broadcast when processing is unchanged" do
      record = create(:monthly_status, user:, month: 8, year: 2026)

      expect {
        record.update!(processing: false, last_processed_at: Time.current)
      }.not_to have_broadcasted_to([ user.id, 2026, 8 ]).from_channel(MonthlyStatusChannel)
    end

    it "does not broadcast when only status changes" do
      record = create(:monthly_status, user:, month: 8, year: 2026)

      expect {
        record.update!(status: Core::MonthlyStatus::Status::CLOSED)
      }.not_to have_broadcasted_to([ user.id, 2026, 8 ]).from_channel(MonthlyStatusChannel)
    end
  end
end
