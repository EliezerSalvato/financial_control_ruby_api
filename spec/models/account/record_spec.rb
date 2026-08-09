require "rails_helper"

RSpec.describe Account::Record, type: :model do
  describe "defaults" do
    it "defaults active to true and current_balance to 0" do
      account = create(:account)

      expect(account.active).to be(true)
      expect(account.current_balance).to eq(0)
    end
  end
end
