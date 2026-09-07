require "rails_helper"

RSpec.describe Settlement::ProcessJob, type: :job do
  include ActiveJob::TestHelper

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

  it "does not retry when item validation failures were already collected" do
    allow(Settlement).to receive(:process).and_return(
      success(failures: [ { kind: :occurrence, type: :insufficient_account_balance } ])
    )

    expect { perform }.not_to have_enqueued_job
  end

  it "does not retry a validation failure" do
    allow(Settlement).to receive(:process).and_return(Solid::Failure(:previous_month_open))

    expect { perform }.not_to have_enqueued_job
  end

  it "retries a generic process failure" do
    allow(Settlement).to receive(:process).and_return(Solid::Failure(:user_not_found))

    expect { perform }.to have_enqueued_job(described_class)
  end

  it "retries when the process raises" do
    allow(Settlement).to receive(:process).and_raise(StandardError, "boom")

    expect { perform }.to have_enqueued_job(described_class)
  end
end
