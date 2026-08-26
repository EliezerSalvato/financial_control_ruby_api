require "rails_helper"

RSpec.describe CreditCard::Repository::Adapters::ActiveRecord do
  subject(:repository) { described_class }

  let(:user) { create(:user, :verified) }
  let(:user_entity) { User::Mapper.to_entity(user) }
  let(:institution) { create(:institution, user:) }
  let(:account) { create(:account, :bank_account, user:, institution:) }

  describe "#list" do
    let!(:active_credit_card) { create(:credit_card, user:, institution:, default_payment_account: account, name: "Platinum", active: true) }
    let!(:inactive_credit_card) do
      create(:credit_card, :inactive, user:, institution:, default_payment_account: account, name: "Archive")
    end

    it "returns Success with the user's credit cards and pagination" do
      result = repository.list(
        user: user_entity,
        filters: {},
        sorting: "active desc, name asc",
        page: 1,
        per_page: 25
      )

      expect(result).to be_a(Solid::Success)
      expect(result.type).to eq(:credit_cards_listed)
      expect(result.value[:credit_cards].map(&:id)).to eq([ active_credit_card.id, inactive_credit_card.id ])
      expect(result.value[:pagination]).to have_attributes(page: 1, per_page: 25, count: 2)
    end

    it "ignores unknown filters" do
      result = repository.list(
        user: user_entity,
        filters: { unknown_field_eq: "x" },
        sorting: "name asc",
        page: 1,
        per_page: 25
      )

      expect(result).to be_a(Solid::Success)
      expect(result.type).to eq(:credit_cards_listed)
      expect(result.value[:credit_cards].map(&:id)).to contain_exactly(active_credit_card.id, inactive_credit_card.id)
    end
  end

  describe "#find_by_id" do
    it "returns Success when the credit card belongs to the user" do
      credit_card = create(:credit_card, user:, institution:, default_payment_account: account, name: "Platinum")

      result = repository.find_by_id(user: user_entity, id: credit_card.id)

      expect(result).to be_a(Solid::Success)
      expect(result.type).to eq(:credit_card_found)
      expect(result.value[:credit_card].id).to eq(credit_card.id)
    end

    it "returns Failure when the credit card belongs to another user" do
      credit_card = create(:credit_card)

      result = repository.find_by_id(user: user_entity, id: credit_card.id)

      expect(result).to be_a(Solid::Failure)
      expect(result.type).to eq(:credit_card_not_found)
    end
  end

  describe "#exists?" do
    before { create(:credit_card, user:, institution:, default_payment_account: account, name: "Platinum") }

    it "is case-insensitive for the same user" do
      expect(repository.exists?(user: user_entity, name: "platinum")).to be(true)
    end

    it "ignores the excluded id" do
      credit_card = CreditCard::Record.find_by!(user_id: user.id, name: "Platinum")

      expect(repository.exists?(user: user_entity, name: "Platinum", excluding_id: credit_card.id)).to be(false)
    end

    it "does not match another user's credit card" do
      expect(repository.exists?(user: user_entity, name: create(:credit_card, name: "Other").name)).to be(false)
    end
  end

  describe "#create" do
    it "creates a credit card for the user" do
      result = repository.create(
        user: user_entity,
        attributes: {
          institution_id: institution.id,
          default_payment_account_id: account.id,
          name: "Platinum",
          total_limit: 5000,
          available_limit: 5000,
          closing_day: 10,
          due_day: 17,
          network: "mastercard",
          allow_negative_available_limit: true,
          active: true
        }
      )

      expect(result).to be_a(Solid::Success)
      expect(result.type).to eq(:credit_card_created)
      expect(result.value[:credit_card]).to have_attributes(
        name: "Platinum",
        network: "mastercard",
        allow_negative_available_limit: true,
        active: true,
        user_id: user.id
      )
    end
  end

  describe "#update" do
    it "updates the credit card attributes" do
      credit_card = CreditCard::Mapper.to_entity(
        create(:credit_card, user:, institution:, default_payment_account: account, name: "Platinum", active: true)
      )

      result = repository.update(credit_card:, attributes: { name: "Ultravioleta", available_limit: 4200, allow_negative_available_limit: true, active: false })

      expect(result).to be_a(Solid::Success)
      expect(result.value[:credit_card]).to have_attributes(
        name: "Ultravioleta",
        available_limit: 4200,
        allow_negative_available_limit: true,
        active: false
      )
    end
  end

  describe "#destroy" do
    it "destroys the credit card" do
      credit_card = CreditCard::Mapper.to_entity(
        create(:credit_card, user:, institution:, default_payment_account: account, name: "Platinum")
      )

      expect { repository.destroy(credit_card:) }.to change(CreditCard::Record, :count).by(-1)
    end
  end
end
