require "rails_helper"

RSpec.describe Core::Transaction::Settlement::Creation do
  let(:user) { create(:user, :verified) }
  let(:user_entity) { User::Mapper.to_entity(user) }
  let(:occurred_on) { Date.new(2026, 8, 11) }

  def settle(transaction_record, occurred_on: self.occurred_on, value: nil, **overrides)
    described_class.call(
      user: user_entity,
      transaction_id: transaction_record.id,
      occurred_on:,
      value: value || transaction_record.recurrences.min_by(&:starts_on).value,
      settled_on: occurred_on,
      **overrides
    )
  end

  def settlement_record_for(transaction_record, occurred_on:)
    Transaction::Settlement::Record.find_by(transaction_id: transaction_record.id, occurred_on:)
  end

  describe "account income" do
    it "credits the account (ADD) and stores account_id in dependencies" do
      account = create(:account, :bank_account, user:, current_balance: 1000)
      transaction_record = create(:transaction, :income, user:, account:, value: 100, starts_on: occurred_on)

      result = settle(transaction_record, value: 100)

      expect(result).to be_a(Solid::Success)
      expect(result.type).to eq(:transaction_settled)
      expect(result.value[:already_settled]).to be(false)
      expect(account.reload.current_balance).to eq(BigDecimal("1100"))
      expect(settlement_record_for(transaction_record, occurred_on:).for_account.account_id).to eq(account.id)
    end
  end

  describe "account expense" do
    it "debits the account (SUBTRACT)" do
      account = create(:account, :bank_account, user:, current_balance: 1000)
      transaction_record = create(:transaction, user:, account:, value: 500, starts_on: occurred_on)

      result = settle(transaction_record, value: 500)

      expect(result).to be_a(Solid::Success)
      expect(account.reload.current_balance).to eq(BigDecimal("500"))
    end
  end

  describe "transfer" do
    it "subtracts from the source and adds to the destination, storing both FKs in dependencies" do
      source = create(:account, :bank_account, user:, name: "NuConta", current_balance: 1000)
      destination = create(:account, :bank_account, user:, name: "Poupar", current_balance: 5000)
      transaction_record = create(
        :transaction,
        :transfer,
        user:,
        source_account: source,
        destination_account: destination,
        value: 800,
        starts_on: occurred_on
      )

      result = settle(transaction_record, value: 800)

      expect(result).to be_a(Solid::Success)
      expect(source.reload.current_balance).to eq(BigDecimal("200"))
      expect(destination.reload.current_balance).to eq(BigDecimal("5800"))
      transfer_dependencies = settlement_record_for(transaction_record, occurred_on:).for_transfer_between_accounts
      expect(transfer_dependencies).to have_attributes(source_account_id: source.id, destination_account_id: destination.id)
    end
  end

  describe "credit card occurrence" do
    let(:credit_card) { create(:credit_card, user:, total_limit: 5000, available_limit: 2000) }

    it "creates for_credit_card only and subtracts limit_consumed from available_limit" do
      transaction_record = create(
        :transaction,
        :with_credit_card,
        user:,
        credit_card:,
        value: 300,
        starts_on: occurred_on,
        limit_consumption_type: "upfront"
      )

      result = settle(transaction_record, value: 300)
      record = settlement_record_for(transaction_record, occurred_on:)

      expect(result).to be_a(Solid::Success)
      expect(record.for_credit_card.limit_consumed).to eq(300)
      expect(record.for_account).to be_nil
      expect(record.for_transfer_between_accounts).to be_nil
      expect(credit_card.reload.available_limit).to eq(BigDecimal("1700"))
    end

    it "consumes value * installments_count on the first upfront installment and 0 on later ones" do
      transaction_record = create(
        :transaction,
        :installment,
        :with_credit_card,
        user:,
        credit_card:,
        value: 100,
        starts_on: Date.new(2026, 8, 11),
        ends_on: Date.new(2026, 9, 11),
        installments_count: 2,
        limit_consumption_type: "upfront"
      )

      first = settle(transaction_record, occurred_on: Date.new(2026, 8, 11), value: 100)
      second = settle(transaction_record, occurred_on: Date.new(2026, 9, 11), value: 100)

      expect(first).to be_a(Solid::Success)
      expect(second).to be_a(Solid::Success)
      expect(settlement_record_for(transaction_record, occurred_on: Date.new(2026, 8, 11)).for_credit_card.limit_consumed).to eq(200)
      expect(settlement_record_for(transaction_record, occurred_on: Date.new(2026, 9, 11)).for_credit_card.limit_consumed).to eq(0)
      expect(credit_card.reload.available_limit).to eq(BigDecimal("1800"))
    end

    it "consumes value on a one_time upfront purchase and keeps installment_number nil" do
      transaction_record = create(
        :transaction,
        :with_credit_card,
        user:,
        credit_card:,
        value: 150,
        starts_on: occurred_on,
        limit_consumption_type: "upfront"
      )

      result = settle(transaction_record, value: 150)
      record = settlement_record_for(transaction_record, occurred_on:)

      expect(result).to be_a(Solid::Success)
      expect(record.installment_number).to be_nil
      expect(record.for_credit_card).to be_present
      expect(record.for_credit_card.limit_consumed).to eq(150)
      expect(credit_card.reload.available_limit).to eq(BigDecimal("1850"))
    end

    it "consumes value on every monthly occurrence" do
      transaction_record = create(
        :transaction,
        :installment,
        :with_credit_card,
        user:,
        credit_card:,
        value: 100,
        starts_on: Date.new(2026, 8, 11),
        ends_on: Date.new(2026, 9, 11),
        installments_count: 2,
        limit_consumption_type: "monthly"
      )

      settle(transaction_record, occurred_on: Date.new(2026, 8, 11), value: 100)
      settle(transaction_record, occurred_on: Date.new(2026, 9, 11), value: 100)

      expect(settlement_record_for(transaction_record, occurred_on: Date.new(2026, 8, 11)).for_credit_card.limit_consumed).to eq(100)
      expect(settlement_record_for(transaction_record, occurred_on: Date.new(2026, 9, 11)).for_credit_card.limit_consumed).to eq(100)
      expect(credit_card.reload.available_limit).to eq(BigDecimal("1800"))
    end
  end

  describe "dependencies" do
    it "does not rewrite the dependencies after the transaction account changes" do
      account = create(:account, :bank_account, user:, current_balance: 1000)
      other_account = create(:account, :bank_account, user:, current_balance: 0)
      transaction_record = create(:transaction, user:, account:, value: 100, starts_on: occurred_on)

      settle(transaction_record, value: 100)
      transaction_record.for_account.update!(account: other_account)

      expect(settlement_record_for(transaction_record, occurred_on:).for_account.account_id).to eq(account.id)
    end
  end

  describe "recurring installment_number" do
    it "assigns 1, then 2, from starts_on" do
      account = create(:account, :bank_account, user:, current_balance: 1000)
      transaction_record = create(:transaction, :recurring, user:, account:, value: 100, starts_on: Date.new(2026, 8, 11))

      settle(transaction_record, occurred_on: Date.new(2026, 8, 11), value: 100)
      settle(transaction_record, occurred_on: Date.new(2026, 9, 11), value: 100)

      expect(settlement_record_for(transaction_record, occurred_on: Date.new(2026, 8, 11)).installment_number).to eq(1)
      expect(settlement_record_for(transaction_record, occurred_on: Date.new(2026, 9, 11)).installment_number).to eq(2)
    end
  end

  describe "has_one exclusivity" do
    it "does not create transaction_settlement_for_credit_cards for an account occurrence" do
      account = create(:account, :bank_account, user:, current_balance: 1000)
      transaction_record = create(:transaction, user:, account:, value: 100, starts_on: occurred_on)

      settle(transaction_record, value: 100)

      expect(settlement_record_for(transaction_record, occurred_on:).for_credit_card).to be_nil
    end

    it "does not create transaction_settlement_for_credit_cards for a transfer" do
      source = create(:account, :bank_account, user:, current_balance: 1000)
      destination = create(:account, :bank_account, user:, current_balance: 5000)
      transaction_record = create(
        :transaction,
        :transfer,
        user:,
        source_account: source,
        destination_account: destination,
        value: 100,
        starts_on: occurred_on
      )

      settle(transaction_record, value: 100)

      expect(settlement_record_for(transaction_record, occurred_on:).for_credit_card).to be_nil
    end
  end

  describe "status transition" do
    it "marks a one_time transaction as completed" do
      account = create(:account, :bank_account, user:, current_balance: 1000)
      transaction_record = create(:transaction, user:, account:, value: 100, starts_on: occurred_on)

      settle(transaction_record, value: 100)

      expect(transaction_record.reload.status).to eq("completed")
    end

    it "moves installment from pending to active, then completed on the last installment" do
      account = create(:account, :bank_account, user:, current_balance: 1000)
      transaction_record = create(
        :transaction,
        :installment,
        user:,
        account:,
        value: 100,
        starts_on: Date.new(2026, 8, 11),
        ends_on: Date.new(2026, 9, 11),
        installments_count: 2
      )

      settle(transaction_record, occurred_on: Date.new(2026, 8, 11), value: 100)
      expect(transaction_record.reload.status).to eq("active")

      settle(transaction_record, occurred_on: Date.new(2026, 9, 11), value: 100)
      expect(transaction_record.reload.status).to eq("completed")
    end

    it "keeps a recurring transaction active" do
      account = create(:account, :bank_account, user:, current_balance: 1000)
      transaction_record = create(:transaction, :recurring, user:, account:, value: 100, starts_on: Date.new(2026, 8, 11))

      settle(transaction_record, occurred_on: Date.new(2026, 8, 11), value: 100)
      settle(transaction_record, occurred_on: Date.new(2026, 9, 11), value: 100)

      expect(transaction_record.reload.status).to eq("active")
    end
  end

  describe "insufficient funds" do
    it "returns Failure(:insufficient_account_balance) and persists no settlement without allow_negative_balance" do
      account = create(:account, :bank_account, user:, current_balance: 100)
      transaction_record = create(:transaction, user:, account:, value: 500, starts_on: occurred_on)

      result = settle(transaction_record, value: 500)

      expect(result).to be_a(Solid::Failure)
      expect(result.type).to eq(:insufficient_account_balance)
      expect(settlement_record_for(transaction_record, occurred_on:)).to be_nil
      expect(account.reload.current_balance).to eq(BigDecimal("100"))
    end

    it "returns Failure(:insufficient_available_limit) and persists no settlement without allow_negative_available_limit" do
      credit_card = create(:credit_card, user:, total_limit: 5000, available_limit: 100)
      transaction_record = create(
        :transaction,
        :with_credit_card,
        user:,
        credit_card:,
        value: 300,
        starts_on: occurred_on
      )

      result = settle(transaction_record, value: 300)

      expect(result).to be_a(Solid::Failure)
      expect(result.type).to eq(:insufficient_available_limit)
      expect(settlement_record_for(transaction_record, occurred_on:)).to be_nil
      expect(credit_card.reload.available_limit).to eq(BigDecimal("100"))
    end

    it "settles an account expense even when the result is negative if the flag is on" do
      account = create(:account, :bank_account, :allow_negative_balance, user:, current_balance: 100)
      transaction_record = create(:transaction, user:, account:, value: 500, starts_on: occurred_on)

      result = settle(transaction_record, value: 500)

      expect(result).to be_a(Solid::Success)
      expect(account.reload.current_balance).to eq(BigDecimal("-400"))
    end

    it "settles a card occurrence even when the result is negative if the flag is on" do
      credit_card = create(:credit_card, :allow_negative_available_limit, user:, total_limit: 5000, available_limit: 100)
      transaction_record = create(
        :transaction,
        :with_credit_card,
        user:,
        credit_card:,
        value: 300,
        starts_on: occurred_on
      )

      result = settle(transaction_record, value: 300)

      expect(result).to be_a(Solid::Success)
      expect(credit_card.reload.available_limit).to eq(BigDecimal("-200"))
    end
  end

  describe "inactive resources" do
    it "settles an occurrence on an inactive account" do
      account = create(:account, :bank_account, :inactive, user:, current_balance: 1000)
      transaction_record = create(:transaction, user:, account:, value: 100, starts_on: occurred_on)

      result = settle(transaction_record, value: 100)

      expect(result).to be_a(Solid::Success)
      expect(account.reload.current_balance).to eq(BigDecimal("900"))
    end

    it "settles an occurrence on an inactive card" do
      credit_card = create(:credit_card, :inactive, user:, total_limit: 5000, available_limit: 2000)
      transaction_record = create(
        :transaction,
        :with_credit_card,
        user:,
        credit_card:,
        value: 100,
        starts_on: occurred_on
      )

      result = settle(transaction_record, value: 100)

      expect(result).to be_a(Solid::Success)
      expect(credit_card.reload.available_limit).to eq(BigDecimal("1900"))
    end
  end

  describe "idempotency" do
    it "exposes already_settled: true on a second call and does not change balance again" do
      account = create(:account, :bank_account, user:, current_balance: 1000)
      transaction_record = create(:transaction, user:, account:, value: 100, starts_on: occurred_on)

      first = settle(transaction_record, value: 100)
      second = settle(transaction_record, value: 100)

      expect(first.value[:already_settled]).to be(false)
      expect(second).to be_a(Solid::Success)
      expect(second.value[:already_settled]).to be(true)
      expect(account.reload.current_balance).to eq(BigDecimal("900"))
      expect(Transaction::Settlement::Record.where(transaction_id: transaction_record.id).count).to eq(1)
    end
  end

  describe "logging" do
    it "never calls Rails.logger" do
      account = create(:account, :bank_account, user:, current_balance: 1000)
      transaction_record = create(:transaction, user:, account:, value: 100, starts_on: occurred_on)

      allow(Rails.logger).to receive(:info)
      allow(Rails.logger).to receive(:warn)
      allow(Rails.logger).to receive(:error)

      settle(transaction_record, value: 100)

      expect(Rails.logger).not_to have_received(:info)
      expect(Rails.logger).not_to have_received(:warn)
      expect(Rails.logger).not_to have_received(:error)
    end
  end

  describe "facade" do
    it "is callable as Transaction.settle" do
      account = create(:account, :bank_account, user:, current_balance: 1000)
      transaction_record = create(:transaction, user:, account:, value: 100, starts_on: occurred_on)

      result = Transaction.settle(
        user: user_entity,
        transaction_id: transaction_record.id,
        occurred_on:,
        value: 100,
        settled_on: occurred_on
      )

      expect(result).to be_a(Solid::Success)
      expect(result.type).to eq(:transaction_settled)
    end
  end
end
