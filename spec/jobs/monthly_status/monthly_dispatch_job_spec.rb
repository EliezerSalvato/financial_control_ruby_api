require "rails_helper"

RSpec.describe MonthlyStatus::MonthlyDispatchJob, type: :job do
  include ActiveJob::TestHelper

  let(:date) { Date.new(2026, 9, 1) }

  it "calls MonthlyStatus.dispatch with date" do
    allow(MonthlyStatus).to receive(:dispatch).and_return(Solid::Success(:monthly_dispatch_completed))

    described_class.perform_now(date:)

    expect(MonthlyStatus).to have_received(:dispatch).with(date:)
  end

  it "retries when dispatch fails" do
    allow(MonthlyStatus).to receive(:dispatch).and_return(Solid::Failure(:invalid_input))

    expect { described_class.perform_now(date:) }.to have_enqueued_job(described_class)
  end

  it "retries when dispatch raises" do
    allow(MonthlyStatus).to receive(:dispatch).and_raise(StandardError, "boom")

    expect { described_class.perform_now(date:) }.to have_enqueued_job(described_class)
  end
end
