require "rails_helper"

RSpec.describe Transaction::Settlement::Repository::Adapters::ActiveRecord do
  subject(:repository) { described_class }

  let(:user) { create(:user, :verified) }
  let(:account) { create(:account, :bank_account, user:, current_balance: 1000) }
  let(:transaction_record) { create(:transaction, user:, account:, value: 100, starts_on: Date.new(2026, 8, 11)) }

  def create_settlement(**overrides)
    repository.create(
      transaction_id: transaction_record.id,
      occurred_on: Date.new(2026, 8, 11),
      settled_on: Date.new(2026, 8, 11),
      value: 100,
      installment_number: nil,
      account_id: account.id,
      **overrides
    )
  end

  describe "#create" do
    it "returns Success(:already_settled) with the existing row on a duplicate (transaction_id, occurred_on)" do
      first = create_settlement
      second = nil

      expect { second = create_settlement(value: 50) }.not_to raise_error

      expect(second).to be_a(Solid::Success)
      expect(second.type).to eq(:already_settled)
      expect(second.value[:settlement]).to have_attributes(
        id: first.value[:settlement].id,
        value: 100,
        occurred_on: Date.new(2026, 8, 11)
      )
      expect(Transaction::Settlement::Record.count).to eq(1)
    end

    it "persists installment_number as nil for a one_time settlement" do
      result = create_settlement(installment_number: nil)

      expect(result).to be_a(Solid::Success)
      expect(result.type).to eq(:transaction_settlement_created)
      expect(result.value[:settlement].installment_number).to be_nil
    end

    it "persists installment_number 1, then 2, for recurring occurrences" do
      recurring = create(:transaction, :recurring, user:, account:, starts_on: Date.new(2026, 8, 11), value: 100)

      first = repository.create(
        transaction_id: recurring.id,
        occurred_on: Date.new(2026, 8, 11),
        settled_on: Date.new(2026, 8, 11),
        value: 100,
        installment_number: 1,
        account_id: account.id
      )
      second = repository.create(
        transaction_id: recurring.id,
        occurred_on: Date.new(2026, 9, 11),
        settled_on: Date.new(2026, 9, 11),
        value: 100,
        installment_number: 2,
        account_id: account.id
      )

      expect(first.value[:settlement].installment_number).to eq(1)
      expect(second.value[:settlement].installment_number).to eq(2)
    end

    it "creates for_credit_card when limit_consumed is present" do
      credit_card = create(:credit_card, user:)
      card_transaction = create(:transaction, :with_credit_card, user:, credit_card:, value: 100)

      result = repository.create(
        transaction_id: card_transaction.id,
        occurred_on: Date.new(2026, 8, 11),
        settled_on: Date.new(2026, 8, 11),
        value: 100,
        installment_number: nil,
        limit_consumed: 100
      )

      expect(result).to be_a(Solid::Success)
      expect(result.value[:settlement]).to have_attributes(limit_consumed: 100, account_id: nil, source_account_id: nil)
      expect(Transaction::Settlement::Record.find(result.value[:settlement].id).for_credit_card).to be_present
      expect(Transaction::Settlement::Record.find(result.value[:settlement].id).for_account).to be_nil
    end

    it "creates for_account when account_id is present" do
      result = create_settlement

      expect(result.value[:settlement].account_id).to eq(account.id)
      expect(Transaction::Settlement::Record.find(result.value[:settlement].id).for_account.account_id).to eq(account.id)
      expect(Transaction::Settlement::Record.find(result.value[:settlement].id).for_credit_card).to be_nil
    end

    it "creates for_transfer_between_accounts when source and destination are present" do
      source = create(:account, :bank_account, user:, current_balance: 1000)
      destination = create(:account, :bank_account, user:, current_balance: 5000)
      transfer = create(:transaction, :transfer, user:, source_account: source, destination_account: destination, value: 800)

      result = repository.create(
        transaction_id: transfer.id,
        occurred_on: Date.new(2026, 8, 11),
        settled_on: Date.new(2026, 8, 11),
        value: 800,
        installment_number: nil,
        source_account_id: source.id,
        destination_account_id: destination.id
      )

      settlement = Transaction::Settlement::Record.find(result.value[:settlement].id)
      expect(settlement.for_transfer_between_accounts).to have_attributes(
        source_account_id: source.id,
        destination_account_id: destination.id
      )
      expect(settlement.for_account).to be_nil
      expect(settlement.for_credit_card).to be_nil
    end
  end

  describe "#settled_keys" do
    it "returns only keys in the requested range" do
      in_range = create_settlement(occurred_on: Date.new(2026, 8, 11))
      repository.create(
        transaction_id: transaction_record.id,
        occurred_on: Date.new(2026, 9, 11),
        settled_on: Date.new(2026, 9, 11),
        value: 100,
        installment_number: nil,
        account_id: account.id
      )
      other = create(:transaction, user:, account:, starts_on: Date.new(2026, 8, 12), value: 50)
      repository.create(
        transaction_id: other.id,
        occurred_on: Date.new(2026, 8, 12),
        settled_on: Date.new(2026, 8, 12),
        value: 50,
        installment_number: nil,
        account_id: account.id
      )

      result = repository.settled_keys(
        transaction_ids: [ transaction_record.id, other.id ],
        occurred_on_range: Date.new(2026, 8, 1)..Date.new(2026, 8, 31)
      )

      expect(result).to be_a(Solid::Success)
      expect(result.type).to eq(:transaction_settlements_listed)
      expect(result.value[:keys]).to contain_exactly(
        [ transaction_record.id, Date.new(2026, 8, 11) ],
        [ other.id, Date.new(2026, 8, 12) ]
      )
      expect(result.value[:keys]).not_to include([ transaction_record.id, Date.new(2026, 9, 11) ])
      expect(in_range).to be_a(Solid::Success)
    end
  end

  describe "#count_for" do
    it "counts the settled occurrences of the transaction" do
      create_settlement(occurred_on: Date.new(2026, 8, 11))
      repository.create(
        transaction_id: transaction_record.id,
        occurred_on: Date.new(2026, 9, 11),
        settled_on: Date.new(2026, 9, 11),
        value: 100,
        installment_number: nil,
        account_id: account.id
      )
      other = create(:transaction, user:, account:, starts_on: Date.new(2026, 8, 12), value: 50)
      repository.create(
        transaction_id: other.id,
        occurred_on: Date.new(2026, 8, 12),
        settled_on: Date.new(2026, 8, 12),
        value: 50,
        installment_number: nil,
        account_id: account.id
      )

      result = repository.count_for(transaction_id: transaction_record.id)

      expect(result).to be_a(Solid::Success)
      expect(result.type).to eq(:transaction_settlements_counted)
      expect(result.value[:count]).to eq(2)
    end
  end
end
