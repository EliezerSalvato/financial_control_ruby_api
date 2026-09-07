require "rails_helper"

RSpec.describe MonthlyStatus::MonthlyClosingJob, type: :job do
  include ActiveJob::TestHelper

  let(:user_id) { SecureRandom.uuid }
  let(:date) { Date.new(2026, 3, 1) }

  def success(still_open: [])
    Solid::Success(:monthly_closing_completed, still_open:)
  end

  it "calls MonthlyStatus.close_open_months with the user_id and date" do
    allow(MonthlyStatus).to receive(:close_open_months).and_return(success)

    described_class.perform_now(user_id:, date:)

    expect(MonthlyStatus).to have_received(:close_open_months).with(user_id:, date:)
  end

  it "does not retry when months remain open after notification" do
    allow(MonthlyStatus).to receive(:close_open_months).and_return(
      success(still_open: [ { month: 8, year: 2026 } ])
    )

    expect { described_class.perform_now(user_id:) }.not_to have_enqueued_job
  end

  it "retries a generic closing failure" do
    allow(MonthlyStatus).to receive(:close_open_months).and_return(Solid::Failure(:invalid_input))

    expect { described_class.perform_now(user_id:) }.to have_enqueued_job(described_class)
  end

  it "retries when closing raises" do
    allow(MonthlyStatus).to receive(:close_open_months).and_raise(StandardError, "boom")

    expect { described_class.perform_now(user_id:) }.to have_enqueued_job(described_class)
  end
end
