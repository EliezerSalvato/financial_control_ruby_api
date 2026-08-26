require "rails_helper"

RSpec.describe Account::Repository::Adapters::ActiveRecord do
  subject(:repository) { described_class }

  let(:user) { create(:user, :verified) }
  let(:user_entity) { User::Mapper.to_entity(user) }

  describe "#list" do
    let!(:active_account) { create(:account, user:, name: "Wallet", active: true) }
    let!(:inactive_account) { create(:account, :inactive, user:, name: "Archive") }

    it "returns Success with the user's accounts and pagination" do
      result = repository.list(
        user: user_entity,
        filters: {},
        sorting: "active desc, name asc",
        page: 1,
        per_page: 25
      )

      expect(result).to be_a(Solid::Success)
      expect(result.type).to eq(:accounts_listed)
      expect(result.value[:accounts].map(&:id)).to eq([ active_account.id, inactive_account.id ])
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
      expect(result.type).to eq(:accounts_listed)
      expect(result.value[:accounts].map(&:id)).to contain_exactly(active_account.id, inactive_account.id)
    end
  end

  describe "#find_by_id" do
    it "returns Success when the account belongs to the user" do
      account = create(:account, user:, name: "Wallet")

      result = repository.find_by_id(user: user_entity, id: account.id)

      expect(result).to be_a(Solid::Success)
      expect(result.type).to eq(:account_found)
      expect(result.value[:account].id).to eq(account.id)
    end

    it "returns Failure when the account belongs to another user" do
      account = create(:account)

      result = repository.find_by_id(user: user_entity, id: account.id)

      expect(result).to be_a(Solid::Failure)
      expect(result.type).to eq(:account_not_found)
    end
  end

  describe "#exists?" do
    before { create(:account, user:, name: "Wallet") }

    it "is case-insensitive for the same user" do
      expect(repository.exists?(user: user_entity, name: "wallet")).to be(true)
    end

    it "ignores the excluded id" do
      account = Account::Record.find_by!(user_id: user.id, name: "Wallet")

      expect(repository.exists?(user: user_entity, name: "Wallet", excluding_id: account.id)).to be(false)
    end

    it "does not match another user's account" do
      expect(repository.exists?(user: user_entity, name: create(:account, name: "Other").name)).to be(false)
    end
  end

  describe "#create" do
    it "creates a cash account for the user" do
      result = repository.create(
        user: user_entity,
        attributes: {
          name: "Wallet",
          kind: "cash",
          color: "#3B82F6",
          allow_negative_balance: true,
          active: true,
          current_balance: 10.5
        }
      )

      expect(result).to be_a(Solid::Success)
      expect(result.type).to eq(:account_created)
      expect(result.value[:account]).to have_attributes(
        name: "Wallet",
        kind: "cash",
        color: "#3B82F6",
        allow_negative_balance: true,
        active: true,
        user_id: user.id,
        institution_id: nil,
        bank_account_type: nil
      )
      expect(result.value[:account].current_balance).to eq(BigDecimal("10.5"))
    end

    it "creates a bank account for the user" do
      institution = create(:institution, user:)

      result = repository.create(
        user: user_entity,
        attributes: {
          name: "Checking",
          kind: "bank_account",
          institution_id: institution.id,
          bank_account_type: "checking",
          color: "#820AD1",
          active: true,
          current_balance: 0
        }
      )

      expect(result).to be_a(Solid::Success)
      expect(result.value[:account]).to have_attributes(
        kind: "bank_account",
        institution_id: institution.id,
        bank_account_type: "checking"
      )
    end
  end

  describe "#update" do
    it "updates the account attributes" do
      account = Account::Mapper.to_entity(create(:account, user:, name: "Wallet", active: true))

      result = repository.update(account:, attributes: { name: "Cash", color: "#10B981", allow_negative_balance: true, active: false })

      expect(result).to be_a(Solid::Success)
      expect(result.value[:account]).to have_attributes(name: "Cash", color: "#10B981", allow_negative_balance: true, active: false)
    end
  end

  describe "#destroy" do
    it "destroys the account" do
      account = Account::Mapper.to_entity(create(:account, user:))

      expect {
        result = repository.destroy(account:)

        expect(result).to be_a(Solid::Success)
        expect(result.type).to eq(:account_destroyed)
      }.to change(Account::Record, :count).by(-1)
    end
  end
end
