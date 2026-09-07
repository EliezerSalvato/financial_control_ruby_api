require "rails_helper"

RSpec.describe Settlement::DailyDispatchJob, type: :job do
  include ActiveJob::TestHelper

  let(:date) { Date.new(2026, 8, 15) }

  it "calls Settlement.dispatch with date" do
    allow(Settlement).to receive(:dispatch).and_return(Solid::Success(:daily_dispatch_completed))

    described_class.perform_now(date:)

    expect(Settlement).to have_received(:dispatch).with(date:)
  end

  it "retries when dispatch fails" do
    allow(Settlement).to receive(:dispatch).and_return(Solid::Failure(:invalid_input))

    expect { described_class.perform_now(date:) }.to have_enqueued_job(described_class)
  end

  it "retries when dispatch raises" do
    allow(Settlement).to receive(:dispatch).and_raise(StandardError, "boom")

    expect { described_class.perform_now(date:) }.to have_enqueued_job(described_class)
  end
end
