require "rails_helper"

RSpec.describe Core::MonthlyStatus::Dispatching do
  include ActiveJob::TestHelper

  let(:date) { Date.new(2026, 9, 1) }

  def dispatch
    described_class.call(date:)
  end

  it "enqueues one MonthlyClosingJob per user with an open month strictly before the given date" do
    user = create(:user, :verified)
    other_user = create(:user, :verified)
    current_only = create(:user, :verified)
    create(:monthly_status, user:, month: 8, year: 2026)
    create(:monthly_status, user:, month: 7, year: 2026)
    create(:monthly_status, user: other_user, month: 8, year: 2026)
    create(:monthly_status, user: current_only, month: 9, year: 2026)
    create(:monthly_status, :closed, user:, month: 6, year: 2026)
    create(:user, :verified)

    expect {
      dispatch
    }.to have_enqueued_job(MonthlyStatus::MonthlyClosingJob).exactly(2).times

    expect(MonthlyStatus::MonthlyClosingJob).to have_been_enqueued.with(user_id: user.id, date:)
    expect(MonthlyStatus::MonthlyClosingJob).to have_been_enqueued.with(user_id: other_user.id, date:)
    expect(MonthlyStatus::MonthlyClosingJob).not_to have_been_enqueued.with(hash_including(user_id: current_only.id))
  end

  it "does not enqueue a job for users who only have the current month open" do
    user = create(:user, :verified)
    create(:monthly_status, user:, month: 9, year: 2026)

    expect {
      dispatch
    }.not_to have_enqueued_job(MonthlyStatus::MonthlyClosingJob)
  end

  describe "facade" do
    it "is callable as MonthlyStatus.dispatch" do
      result = MonthlyStatus.dispatch(date:)

      expect(result).to be_a(Solid::Success)
      expect(result.type).to eq(:monthly_dispatch_completed)
    end
  end
end
