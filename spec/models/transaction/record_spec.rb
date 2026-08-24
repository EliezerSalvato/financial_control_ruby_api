require "rails_helper"

RSpec.describe Transaction::Record, type: :model do
  it "persists with associations" do
    transaction = create(:transaction)

    expect(transaction.for_account).to be_present
    expect(transaction.recurrences.count).to eq(1)
  end

  it "defaults status to pending" do
    transaction = create(:transaction)

    expect(transaction.status).to eq("pending")
    expect(transaction.canceled_on).to be_nil
  end

  it "requires canceled_on when status is canceled" do
    expect {
      create(:transaction, status: "canceled", canceled_on: nil)
    }.to raise_error(ActiveRecord::StatementInvalid)
  end

  it "rejects canceled_on when status is not canceled" do
    expect {
      create(:transaction, canceled_on: Date.current)
    }.to raise_error(ActiveRecord::StatementInvalid)
  end
end
