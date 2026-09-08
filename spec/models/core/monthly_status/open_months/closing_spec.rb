require "rails_helper"

RSpec.describe Core::MonthlyStatus::OpenMonths::Closing do
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

  def close_open_months
    described_class.call(user_id: user.id)
  end

  it "calls Closing for each open month strictly before the given date, ignoring later months even when today is after that date" do
    create(:monthly_status, user:, month: 1, year: 2026)
    create(:monthly_status, user:, month: 2, year: 2026)
    create(:monthly_status, user:, month: 3, year: 2026)
    create(:monthly_status, user:, month: 8, year: 2026)
    allow(Core::MonthlyStatus::Closing).to receive(:call).and_return(closed_result)

    travel_to(Date.new(2026, 9, 7)) do
      described_class.call(user_id: user.id, date: Date.new(2026, 3, 1))
    end

    expect(Core::MonthlyStatus::Closing).to have_received(:call).with(user_id: user.id, month: 1, year: 2026)
    expect(Core::MonthlyStatus::Closing).to have_received(:call).with(user_id: user.id, month: 2, year: 2026)
    expect(Core::MonthlyStatus::Closing).not_to have_received(:call).with(user_id: user.id, month: 3, year: 2026)
    expect(Core::MonthlyStatus::Closing).not_to have_received(:call).with(user_id: user.id, month: 8, year: 2026)
  end

  it "calls Closing for each open month strictly before the current one" do
    create(:monthly_status, user:, month: 7, year: 2026)
    create(:monthly_status, user:, month: 8, year: 2026)
    create(:monthly_status, user:, month: 9, year: 2026)
    create(:monthly_status, :closed, user:, month: 6, year: 2026)
    allow(Core::MonthlyStatus::Closing).to receive(:call).and_return(closed_result)

    travel_to(Date.new(2026, 9, 1)) { close_open_months }

    expect(Core::MonthlyStatus::Closing).to have_received(:call).with(user_id: user.id, month: 7, year: 2026)
    expect(Core::MonthlyStatus::Closing).to have_received(:call).with(user_id: user.id, month: 8, year: 2026)
    expect(Core::MonthlyStatus::Closing).not_to have_received(:call).with(user_id: user.id, month: 9, year: 2026)
    expect(Core::MonthlyStatus::Closing).not_to have_received(:call).with(user_id: user.id, month: 6, year: 2026)
  end

  it "creates the previous month when missing and calls Closing for it" do
    allow(Core::MonthlyStatus::Closing).to receive(:call).and_return(closed_result)

    expect {
      travel_to(Date.new(2026, 9, 1)) { close_open_months }
    }.to change(MonthlyStatus::Record, :count).by(1)

    expect(MonthlyStatus::Record.find_by!(user_id: user.id, month: 8, year: 2026)).to have_attributes(
      status: "open"
    )
    expect(Core::MonthlyStatus::Closing).to have_received(:call).with(user_id: user.id, month: 8, year: 2026)
  end

  it "does not create the previous month when a later month is already closed" do
    create(:monthly_status, user:, month: 1, year: 2026)
    create(:monthly_status, :closed, user:, month: 8, year: 2026)
    allow(Core::MonthlyStatus::Closing).to receive(:call).and_return(closed_result)

    expect {
      travel_to(Date.new(2026, 9, 7)) do
        described_class.call(user_id: user.id, date: Date.new(2026, 3, 1))
      end
    }.not_to change { MonthlyStatus::Record.exists?(user_id: user.id, month: 2, year: 2026) }.from(false)

    expect(Core::MonthlyStatus::Closing).to have_received(:call).with(user_id: user.id, month: 1, year: 2026)
    expect(Core::MonthlyStatus::Closing).not_to have_received(:call).with(user_id: user.id, month: 2, year: 2026)
  end

  it "does not notify and does not schedule anything when all months close" do
    create(:monthly_status, user:, month: 8, year: 2026)
    allow(Core::MonthlyStatus::Closing).to receive(:call).and_return(closed_result)
    allow(Core::MonthlyStatus::Closing::ValidationErrorNotifying).to receive(:call)
    allow(Core::MonthlyStatus::Closing::UnexpectedErrorNotifying).to receive(:call)

    expect {
      travel_to(Date.new(2026, 9, 10)) { close_open_months }
    }.not_to have_enqueued_job(MonthlyStatus::MonthlyClosingJob)

    expect(Core::MonthlyStatus::Closing::ValidationErrorNotifying).not_to have_received(:call)
    expect(Core::MonthlyStatus::Closing::UnexpectedErrorNotifying).not_to have_received(:call)
  end

  it "raises when notifying pending months fails" do
    create(:monthly_status, user:, month: 8, year: 2026)
    allow(Core::MonthlyStatus::Closing).to receive(:call).and_return(
      kept_open_result(pending_occurrences: [ { description: "Rent" } ])
    )
    allow(Core::MonthlyStatus::Closing::ValidationErrorNotifying).to receive(:call)
      .and_return(Solid::Failure(:notifications_creation_failed))

    expect {
      travel_to(Date.new(2026, 9, 10)) { close_open_months }
    }.to raise_error(StandardError, "notifications_creation_failed")
  end

  it "notifies pending items and schedules a retry for day 11 at 05:00 in the app time zone when a month remains open on day 10" do
    monthly_status = create(:monthly_status, user:, month: 8, year: 2026)
    pending_occurrences = [ { transaction_id: SecureRandom.uuid, occurred_on: Date.new(2026, 8, 11), description: "Rent" } ]
    pending_invoices = [ { credit_card_id: SecureRandom.uuid, due_date: Date.new(2026, 8, 17) } ]
    allow(Core::MonthlyStatus::Closing).to receive(:call).and_return(kept_open_result(pending_occurrences:, pending_invoices:))
    allow(Core::MonthlyStatus::Closing::ValidationErrorNotifying).to receive(:call).and_return(Solid::Success(:notifications_created))

    expect {
      travel_to(Time.zone.local(2026, 9, 10, 12, 0, 0)) { close_open_months }
    }.to have_enqueued_job(MonthlyStatus::MonthlyClosingJob)
      .with(user_id: user.id, date: Date.new(2026, 9, 10))
      .at(Time.zone.local(2026, 9, 11, 5, 0, 0))

    expect(Core::MonthlyStatus::Closing::ValidationErrorNotifying).to have_received(:call).with(
      user_id: user.id,
      pending: [
        {
          month: 8,
          year: 2026,
          monthly_status_id: monthly_status.id,
          pending_occurrences:,
          pending_invoices:
        }
      ]
    )
  end

  it "preserves the given date when scheduling a retry later in the current calendar month" do
    create(:monthly_status, user:, month: 2, year: 2026)
    allow(Core::MonthlyStatus::Closing).to receive(:call).and_return(
      kept_open_result(pending_occurrences: [ { description: "Rent" } ])
    )
    allow(Core::MonthlyStatus::Closing::ValidationErrorNotifying).to receive(:call)
      .and_return(Solid::Success(:notifications_created))

    cutoff_date = Date.new(2026, 3, 1)

    expect {
      travel_to(Time.zone.local(2026, 9, 10, 12, 0, 0)) do
        described_class.call(user_id: user.id, date: cutoff_date)
      end
    }.to have_enqueued_job(MonthlyStatus::MonthlyClosingJob)
      .with(user_id: user.id, date: cutoff_date)
      .at(Time.zone.local(2026, 9, 11, 5, 0, 0))
  end

  it "notifies but does not schedule when an open month remains on the last day of the month" do
    monthly_status = create(:monthly_status, user:, month: 8, year: 2026)
    pending_occurrences = [ { transaction_id: SecureRandom.uuid, occurred_on: Date.new(2026, 8, 11), description: "Rent" } ]
    allow(Core::MonthlyStatus::Closing).to receive(:call).and_return(kept_open_result(pending_occurrences:))
    allow(Core::MonthlyStatus::Closing::ValidationErrorNotifying).to receive(:call).and_return(Solid::Success(:notifications_created))

    expect {
      travel_to(Time.zone.local(2026, 9, 30, 12, 0, 0)) { close_open_months }
    }.not_to have_enqueued_job(MonthlyStatus::MonthlyClosingJob)

    expect(Core::MonthlyStatus::Closing::ValidationErrorNotifying).to have_received(:call).with(
      user_id: user.id,
      pending: [
        hash_including(month: 8, year: 2026, monthly_status_id: monthly_status.id, pending_occurrences:)
      ]
    )
  end

  it "notifies an unexpected error and re-raises" do
    create(:monthly_status, user:, month: 8, year: 2026)
    original = StandardError.new("boom")
    allow(Core::MonthlyStatus::Closing).to receive(:call).and_raise(original)
    allow(Core::MonthlyStatus::Closing::UnexpectedErrorNotifying).to receive(:call)
      .and_return(Solid::Success(:error_notified))

    expect {
      travel_to(Date.new(2026, 9, 10)) { close_open_months }
    }.to raise_error { |error| expect(error).to equal(original) }

    expect(Core::MonthlyStatus::Closing::UnexpectedErrorNotifying).to have_received(:call).with(
      user_id: user.id,
      type: :unexpected,
      error: "StandardError"
    )
  end

  it "re-raises the original error when unexpected notifying fails" do
    create(:monthly_status, user:, month: 8, year: 2026)
    original = StandardError.new("boom")
    allow(Core::MonthlyStatus::Closing).to receive(:call).and_raise(original)
    allow(Core::MonthlyStatus::Closing::UnexpectedErrorNotifying).to receive(:call)
      .and_raise(StandardError, "notify failed")

    expect {
      travel_to(Date.new(2026, 9, 10)) { close_open_months }
    }.to raise_error { |error| expect(error).to equal(original) }
  end

  describe "facade" do
    it "is callable as MonthlyStatus.close_open_months" do
      create(:monthly_status, user:, month: 8, year: 2026)
      allow(Core::MonthlyStatus::Closing).to receive(:call).and_return(closed_result)

      result = nil
      travel_to(Date.new(2026, 9, 10)) { result = MonthlyStatus.close_open_months(user_id: user.id) }

      expect(result).to be_a(Solid::Success)
      expect(result.type).to eq(:monthly_closing_completed)
    end
  end
end
