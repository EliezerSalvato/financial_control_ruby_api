require "rails_helper"

RSpec.describe Account::Record, type: :model do
  describe "defaults" do
    it "defaults active to true, allow_negative_balance to false, and current_balance to 0" do
      account = create(:account)

      expect(account.active).to be(true)
      expect(account.allow_negative_balance).to be(false)
      expect(account.current_balance).to eq(0)
    end
  end
end
