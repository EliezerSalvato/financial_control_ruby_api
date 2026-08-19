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
  end
end
