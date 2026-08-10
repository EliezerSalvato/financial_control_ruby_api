require "rails_helper"

RSpec.describe CreditCard::Record, type: :model do
  describe "defaults" do
    it "defaults active to true and limits to 0 when omitted at persistence layer" do
      credit_card = create(:credit_card)

      expect(credit_card.active).to be(true)
      expect(credit_card.total_limit).to eq(5000)
      expect(credit_card.available_limit).to eq(5000)
    end
  end
end
