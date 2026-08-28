require "rails_helper"
require "rake"

RSpec.describe "monthly_statuses:backfill" do
  include ActiveSupport::Testing::TimeHelpers

  subject(:invoke_backfill) { task.invoke }

  let(:task) { Rake::Task["monthly_statuses:backfill"] }

  before(:all) do
    Rails.application.load_tasks
  end

  before do
    task.reenable
    allow($stdout).to receive(:puts)
  end

  around do |example|
    travel_to(Time.zone.local(2026, 8, 28, 12, 0, 0)) { example.run }
  end

  it "creates open rows from the oldest transaction month through the current month" do
    user = create(:user, :verified)
    create(:transaction, user:, starts_on: Date.new(2026, 1, 15))

    expect { invoke_backfill }.to change(MonthlyStatus::Record, :count).by(8)

    rows = MonthlyStatus::Record.where(user_id: user.id).order(:year, :month)
    expect(rows.map { |row| [ row.month, row.year ] }).to eq((1..8).map { |month| [ month, 2026 ] })
    expect(rows).to all(have_attributes(status: "open"))
  end

  it "creates no rows for a user with no transactions" do
    create(:user, :verified)

    expect { invoke_backfill }.not_to change(MonthlyStatus::Record, :count)
  end

  it "walks every user" do
    first_user = create(:user, :verified)
    second_user = create(:user, :verified)
    create(:transaction, user: first_user, starts_on: Date.new(2026, 7, 1))
    create(:transaction, user: second_user, starts_on: Date.new(2026, 8, 1))

    invoke_backfill

    expect(MonthlyStatus::Record.where(user_id: first_user.id).count).to eq(2)
    expect(MonthlyStatus::Record.where(user_id: second_user.id).count).to eq(1)
  end

  it "does not duplicate rows or reopen a closed month when run twice" do
    user = create(:user, :verified)
    create(:transaction, user:, starts_on: Date.new(2026, 6, 1))
    create(:monthly_status, :closed, user:, month: 7, year: 2026)

    invoke_backfill
    task.reenable
    expect { invoke_backfill }.not_to change(MonthlyStatus::Record, :count)

    expect(MonthlyStatus::Record.find_by!(user_id: user.id, month: 7, year: 2026).status).to eq("closed")
    expect(MonthlyStatus::Record.where(user_id: user.id).order(:month).pluck(:month, :status)).to eq(
      [ [ 6, "open" ], [ 7, "closed" ], [ 8, "open" ] ]
    )
  end
end
