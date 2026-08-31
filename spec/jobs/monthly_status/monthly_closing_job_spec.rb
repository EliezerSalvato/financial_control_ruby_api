require "rails_helper"

RSpec.describe MonthlyStatus::MonthlyClosingJob, type: :job do
  include ActiveJob::TestHelper
  include ActiveSupport::Testing::TimeHelpers

  let(:user) { create(:user, :verified) }

  def closed_result
    Solid::Success(:monthly_status_closed, monthly_status: instance_double(Core::MonthlyStatus::Entity))
  end

  def kept_open_result(pending_occurrences: [], pending_invoices: [])
    Solid::Success(
      :monthly_status_kept_open,
      monthly_status: instance_double(Core::MonthlyStatus::Entity),
      pending_occurrences:,
      pending_invoices:
    )
  end

  it "calls MonthlyStatus.close for each open month strictly before the current one" do
    create(:monthly_status, user:, month: 7, year: 2026)
    create(:monthly_status, user:, month: 8, year: 2026)
    create(:monthly_status, user:, month: 9, year: 2026)
    create(:monthly_status, :closed, user:, month: 6, year: 2026)
    allow(MonthlyStatus).to receive(:close).and_return(closed_result)

    travel_to(Date.new(2026, 9, 1)) { described_class.perform_now(user_id: user.id) }

    expect(MonthlyStatus).to have_received(:close).with(user_id: user.id, month: 7, year: 2026)
    expect(MonthlyStatus).to have_received(:close).with(user_id: user.id, month: 8, year: 2026)
    expect(MonthlyStatus).not_to have_received(:close).with(user_id: user.id, month: 9, year: 2026)
    expect(MonthlyStatus).not_to have_received(:close).with(user_id: user.id, month: 6, year: 2026)
  end

  it "does not log and does not schedule anything when all months close" do
    create(:monthly_status, user:, month: 8, year: 2026)
    allow(MonthlyStatus).to receive(:close).and_return(closed_result)
    allow(Rails.logger).to receive(:warn)

    expect {
      travel_to(Date.new(2026, 9, 10)) { described_class.perform_now(user_id: user.id) }
    }.not_to have_enqueued_job(described_class)

    expect(Rails.logger).not_to have_received(:warn)
  end

  it "logs pending items and schedules a retry for day 11 at 05:00 UTC when a month remains open on day 10" do
    create(:monthly_status, user:, month: 8, year: 2026)
    pending_occurrences = [ { transaction_id: SecureRandom.uuid, occurred_on: Date.new(2026, 8, 11), description: "Rent" } ]
    pending_invoices = [ { credit_card_id: SecureRandom.uuid, due_date: Date.new(2026, 8, 17) } ]
    allow(MonthlyStatus).to receive(:close).and_return(kept_open_result(pending_occurrences:, pending_invoices:))
    allow(Rails.logger).to receive(:warn)

    expect {
      travel_to(Time.utc(2026, 9, 10, 12, 0, 0)) { described_class.perform_now(user_id: user.id) }
    }.to have_enqueued_job(described_class).with(user_id: user.id).at(Time.utc(2026, 9, 11, 5, 0, 0))

    expect(Rails.logger).to have_received(:warn).with(
      a_string_including("[monthly_status] months not closed", "user_id=#{user.id}", "Rent")
    )
  end

  it "logs but does not schedule when an open month remains on the last day of the month" do
    create(:monthly_status, user:, month: 8, year: 2026)
    allow(MonthlyStatus).to receive(:close).and_return(
      kept_open_result(pending_occurrences: [ { transaction_id: SecureRandom.uuid, occurred_on: Date.new(2026, 8, 11), description: "Rent" } ])
    )
    allow(Rails.logger).to receive(:warn)

    expect {
      travel_to(Time.utc(2026, 9, 30, 12, 0, 0)) { described_class.perform_now(user_id: user.id) }
    }.not_to have_enqueued_job(described_class)

    expect(Rails.logger).to have_received(:warn).once
  end
end
