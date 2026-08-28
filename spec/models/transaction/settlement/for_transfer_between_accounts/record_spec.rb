require "rails_helper"

RSpec.describe Transaction::Settlement::ForTransferBetweenAccounts::Record, type: :model do
  it "rejects the same source and destination account" do
    account = create(:account)

    expect {
      create(:transaction_settlement_for_transfer_between_accounts, source_account: account, destination_account: account)
    }.to raise_error(ActiveRecord::StatementInvalid)
  end
end
