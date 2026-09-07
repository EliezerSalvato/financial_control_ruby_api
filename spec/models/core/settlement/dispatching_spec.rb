require "rails_helper"

RSpec.describe Core::Settlement::Dispatching do
  include ActiveJob::TestHelper

  let(:date) { Date.new(2026, 8, 15) }

  def dispatch
    described_class.call(date:)
  end

  it "enqueues one ProcessJob per open non-future month whose previous month is not open" do
    user = create(:user, :verified)
    other_user = create(:user, :verified)
    create(:monthly_status, user:, month: 8, year: 2026)
    create(:monthly_status, user:, month: 7, year: 2026)
    create(:monthly_status, :closed, user:, month: 6, year: 2026)
    create(:monthly_status, user:, month: 9, year: 2026)
    create(:monthly_status, user: other_user, month: 8, year: 2026)
    create(:user, :verified)

    dispatch

    expect(Settlement::ProcessJob).to have_been_enqueued.exactly(2).times
    expect(Settlement::ProcessJob).not_to have_been_enqueued.with(hash_including(user_id: user.id, month: 8, year: 2026))
    expect(Settlement::ProcessJob).to have_been_enqueued.with(
      user_id: user.id,
      month: 7,
      year: 2026,
      reference_date: Date.new(2026, 7, 31)
    )
    expect(Settlement::ProcessJob).to have_been_enqueued.with(
      user_id: other_user.id,
      month: 8,
      year: 2026,
      reference_date: Date.new(2026, 8, 14)
    )
  end

  it "enqueues a month when the previous month is closed" do
    user = create(:user, :verified)
    create(:monthly_status, :closed, user:, month: 7, year: 2026)
    create(:monthly_status, user:, month: 8, year: 2026)

    dispatch

    expect(Settlement::ProcessJob).to have_been_enqueued.once.with(
      user_id: user.id,
      month: 8,
      year: 2026,
      reference_date: Date.new(2026, 8, 14)
    )
  end

  it "enqueues a month when the previous month has no open monthly status" do
    user = create(:user, :verified)
    create(:monthly_status, user:, month: 8, year: 2026)

    dispatch

    expect(Settlement::ProcessJob).to have_been_enqueued.once.with(
      user_id: user.id,
      month: 8,
      year: 2026,
      reference_date: Date.new(2026, 8, 14)
    )
  end

  it "does not enqueue a job when reference_date is nil" do
    user = create(:user, :verified)
    create(:monthly_status, user:, month: 8, year: 2026)

    expect {
      described_class.call(date: Date.new(2026, 8, 1))
    }.not_to have_enqueued_job(Settlement::ProcessJob)
  end

  it "does not enqueue a month that precedes a closed month" do
    user = create(:user, :verified)
    create(:monthly_status, user:, month: 7, year: 2026)
    create(:monthly_status, :closed, user:, month: 8, year: 2026)

    expect {
      dispatch
    }.not_to have_enqueued_job(Settlement::ProcessJob)
  end

  it "does not enqueue a month that precedes a closed month in the next year" do
    user = create(:user, :verified)
    create(:monthly_status, user:, month: 12, year: 2025)
    create(:monthly_status, :closed, user:, month: 1, year: 2026)

    expect {
      dispatch
    }.not_to have_enqueued_job(Settlement::ProcessJob)
  end

  it "does not treat another user's later closed month as a blocker" do
    user = create(:user, :verified)
    other_user = create(:user, :verified)
    create(:monthly_status, user:, month: 8, year: 2026)
    create(:monthly_status, :closed, user: other_user, month: 9, year: 2026)

    dispatch

    expect(Settlement::ProcessJob).to have_been_enqueued.once.with(
      user_id: user.id,
      month: 8,
      year: 2026,
      reference_date: Date.new(2026, 8, 14)
    )
  end

  describe "facade" do
    it "is callable as Settlement.dispatch" do
      result = Settlement.dispatch(date:)

      expect(result).to be_a(Solid::Success)
      expect(result.type).to eq(:daily_dispatch_completed)
    end
  end
end
