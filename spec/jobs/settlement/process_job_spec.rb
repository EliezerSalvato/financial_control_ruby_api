require "rails_helper"

RSpec.describe Settlement::ProcessJob, type: :job do
  let(:user_id) { SecureRandom.uuid }
  let(:month) { 8 }
  let(:year) { 2026 }
  let(:reference_date) { Date.new(2026, 8, 14) }

  def perform
    described_class.perform_now(user_id:, month:, year:, reference_date:)
  end

  def success(failures: [])
    Solid::Success(:settlements_completed, settled_count: 0, invoices_count: 0, failures:)
  end

  it "calls Settlement.process with the four arguments" do
    allow(Settlement).to receive(:process).and_return(success)

    perform

    expect(Settlement).to have_received(:process).with(user_id:, month:, year:, reference_date:)
  end

  it "does not log when failures is empty" do
    allow(Settlement).to receive(:process).and_return(success)
    allow(Rails.logger).to receive(:warn)
    allow(Rails.logger).to receive(:error)

    perform

    expect(Rails.logger).not_to have_received(:warn)
    expect(Rails.logger).not_to have_received(:error)
  end

  it "logs a warning once when failures are present and does not enqueue anything" do
    failures = [ { kind: :occurrence, transaction_id: SecureRandom.uuid, type: :insufficient_account_balance } ]
    allow(Settlement).to receive(:process).and_return(success(failures:))
    allow(Rails.logger).to receive(:warn)

    expect { perform }.not_to have_enqueued_job

    expect(Rails.logger).to have_received(:warn).once
  end

  it "logs an error when the process fails and does not enqueue anything" do
    allow(Settlement).to receive(:process).and_return(Solid::Failure(:previous_month_open))
    allow(Rails.logger).to receive(:error)

    expect { perform }.not_to have_enqueued_job

    expect(Rails.logger).to have_received(:error).once
  end
end
