require "rails_helper"

RSpec.describe Institution::Record, type: :model do
  describe "defaults" do
    it "defaults active to true" do
      expect(create(:institution).active).to be(true)
    end
  end

  describe "dependent destroy" do
    it "destroys linked accounts and credit cards" do
      user = create(:user, :verified)
      institution = create(:institution, user:)
      account = create(:account, :bank_account, user:, institution:)
      create(:credit_card, user:, institution:, default_payment_account: account)

      expect { institution.destroy }.to change(Account::Record, :count).by(-1)
        .and change(CreditCard::Record, :count).by(-1)
    end
  end
end
