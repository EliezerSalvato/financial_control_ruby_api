require "rails_helper"

RSpec.describe Transaction::Repository::Adapters::ActiveRecord do
  subject(:repository) { described_class }

  let(:user) { create(:user, :verified) }
  let(:user_entity) { User::Mapper.to_entity(user) }
  let(:category) { create(:category, user:) }

  describe "#exists_by_category_id?" do
    it "is true when the user has a transaction with the category" do
      create(:transaction, user:, category:)

      expect(repository.exists_by_category_id?(user: user_entity, category_id: category.id)).to be(true)
    end

    it "is false when the user has no transaction with the category" do
      expect(repository.exists_by_category_id?(user: user_entity, category_id: category.id)).to be(false)
    end

    it "does not match another user's transaction" do
      other_user = create(:user, :verified)
      other_category = create(:category, user: other_user)
      create(:transaction, user: other_user, category: other_category)

      expect(repository.exists_by_category_id?(user: user_entity, category_id: other_category.id)).to be(false)
    end
  end

  describe "#exists_by_institution_id?" do
    let(:institution) { create(:institution, user:) }
    let(:account) { create(:account, :bank_account, user:, institution:) }

    it "is true when an account of the institution is used by a transaction" do
      create(:transaction, user:, account:)

      expect(repository.exists_by_institution_id?(user: user_entity, institution_id: institution.id)).to be(true)
    end

    it "is true when a credit card of the institution is used by a transaction" do
      credit_card = create(:credit_card, user:, institution:, default_payment_account: account)
      create(:transaction, :with_credit_card, user:, credit_card:)

      expect(repository.exists_by_institution_id?(user: user_entity, institution_id: institution.id)).to be(true)
    end

    it "is true when an account of the institution is used as a transfer source" do
      create(:transaction, :transfer, user:, source_account: account, destination_account: create(:account, user:))

      expect(repository.exists_by_institution_id?(user: user_entity, institution_id: institution.id)).to be(true)
    end

    it "is true when an account of the institution is used as a transfer destination" do
      create(:transaction, :transfer, user:, source_account: create(:account, user:), destination_account: account)

      expect(repository.exists_by_institution_id?(user: user_entity, institution_id: institution.id)).to be(true)
    end

    it "is false when the institution has no accounts or credit cards used by transactions" do
      create(:account, :bank_account, user:, institution:)
      create(:credit_card, user:, institution:, default_payment_account: account)

      expect(repository.exists_by_institution_id?(user: user_entity, institution_id: institution.id)).to be(false)
    end

    it "does not match another user's institution" do
      other_user = create(:user, :verified)
      other_institution = create(:institution, user: other_user)
      other_account = create(:account, :bank_account, user: other_user, institution: other_institution)
      create(:transaction, user: other_user, account: other_account)

      expect(repository.exists_by_institution_id?(user: user_entity, institution_id: other_institution.id)).to be(false)
    end
  end

  describe "#exists_by_account_id?" do
    let(:account) { create(:account, user:) }

    it "is true when the account is used by a transaction" do
      create(:transaction, user:, account:)

      expect(repository.exists_by_account_id?(user: user_entity, account_id: account.id)).to be(true)
    end

    it "is true when the account is used as a transfer source" do
      create(:transaction, :transfer, user:, source_account: account, destination_account: create(:account, user:))

      expect(repository.exists_by_account_id?(user: user_entity, account_id: account.id)).to be(true)
    end

    it "is true when the account is used as a transfer destination" do
      create(:transaction, :transfer, user:, source_account: create(:account, user:), destination_account: account)

      expect(repository.exists_by_account_id?(user: user_entity, account_id: account.id)).to be(true)
    end

    it "is false when the account is not used by transactions" do
      expect(repository.exists_by_account_id?(user: user_entity, account_id: account.id)).to be(false)
    end

    it "does not match another user's transaction" do
      other_user = create(:user, :verified)
      other_account = create(:account, user: other_user)
      create(:transaction, user: other_user, account: other_account)

      expect(repository.exists_by_account_id?(user: user_entity, account_id: other_account.id)).to be(false)
    end
  end

  describe "#exists_by_credit_card_id?" do
    let(:institution) { create(:institution, user:) }
    let(:account) { create(:account, :bank_account, user:, institution:) }
    let(:credit_card) { create(:credit_card, user:, institution:, default_payment_account: account) }

    it "is true when the credit card is used by a transaction" do
      create(:transaction, :with_credit_card, user:, credit_card:)

      expect(repository.exists_by_credit_card_id?(user: user_entity, credit_card_id: credit_card.id)).to be(true)
    end

    it "is false when the credit card is not used by transactions" do
      expect(repository.exists_by_credit_card_id?(user: user_entity, credit_card_id: credit_card.id)).to be(false)
    end

    it "does not match another user's transaction" do
      other_user = create(:user, :verified)
      other_institution = create(:institution, user: other_user)
      other_account = create(:account, :bank_account, user: other_user, institution: other_institution)
      other_credit_card = create(:credit_card, user: other_user, institution: other_institution, default_payment_account: other_account)
      create(:transaction, :with_credit_card, user: other_user, credit_card: other_credit_card)

      expect(repository.exists_by_credit_card_id?(user: user_entity, credit_card_id: other_credit_card.id)).to be(false)
    end
  end
end
