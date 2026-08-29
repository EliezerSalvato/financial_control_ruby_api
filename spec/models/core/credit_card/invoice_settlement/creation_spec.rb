require "rails_helper"

RSpec.describe Core::CreditCard::InvoiceSettlement::Creation do
  let(:user) { create(:user, :verified) }
  let(:user_entity) { User::Mapper.to_entity(user) }
  let(:account) { create(:account, :bank_account, user:, current_balance: 1000) }
  let(:credit_card) { create(:credit_card, user:, default_payment_account: account, total_limit: 5000, available_limit: 2000) }

  def settle_invoice(**overrides)
    described_class.call(
      user: user_entity,
      credit_card_id: credit_card.id,
      payment_account_id: account.id,
      opening_date: Date.new(2026, 7, 11),
      closing_date: Date.new(2026, 8, 10),
      due_date: Date.new(2026, 8, 17),
      total_value: 100,
      settled_on: Date.new(2026, 8, 17),
      **overrides
    )
  end

  def settle_card_occurrence(transaction, occurred_on:, value:)
    create(
      :transaction_settlement,
      :for_credit_card,
      financial_transaction: transaction,
      occurred_on:,
      settled_on: occurred_on,
      value:
    )
  end

  describe "payment" do
    it "debits the payment account, releases the limit, and links cycle occurrences" do
      in_cycle = create(:transaction, :with_credit_card, user:, credit_card:, starts_on: Date.new(2026, 8, 1), value: 100)
      settlement = settle_card_occurrence(in_cycle, occurred_on: Date.new(2026, 8, 1), value: 100)

      result = settle_invoice(total_value: 100)

      expect(result).to be_a(Solid::Success)
      expect(result.type).to eq(:credit_card_invoice_settled)
      expect(result.value[:already_settled]).to be(false)
      expect(account.reload.current_balance).to eq(BigDecimal("900"))
      expect(credit_card.reload.available_limit).to eq(BigDecimal("2100"))
      expect(settlement.for_credit_card.reload.credit_card_invoice_settlement_id).to eq(result.value[:invoice_settlement].id)
      expect(result.value[:invoice_settlement].released_limit).to eq(100)
    end
  end

  describe "idempotency" do
    it "exposes already_settled on a second call without debiting or releasing again" do
      first = settle_invoice(total_value: 100)
      second = settle_invoice(total_value: 100)

      expect(first.value[:already_settled]).to be(false)
      expect(second).to be_a(Solid::Success)
      expect(second.value[:already_settled]).to be(true)
      expect(account.reload.current_balance).to eq(BigDecimal("900"))
      expect(credit_card.reload.available_limit).to eq(BigDecimal("2100"))
      expect(CreditCard::InvoiceSettlement::Record.count).to eq(1)
    end
  end

  describe "limit ceiling" do
    it "returns Failure(:available_limit_exceeds_total_limit) with rollback when the release would exceed total_limit" do
      credit_card.update!(available_limit: 5000)

      result = settle_invoice(total_value: 100)

      expect(result).to be_a(Solid::Failure)
      expect(result.type).to eq(:available_limit_exceeds_total_limit)
      expect(account.reload.current_balance).to eq(BigDecimal("1000"))
      expect(credit_card.reload.available_limit).to eq(BigDecimal("5000"))
      expect(CreditCard::InvoiceSettlement::Record.count).to eq(0)
    end
  end

  describe "insufficient payment-account balance" do
    it "returns Failure(:insufficient_account_balance) with rollback when the flag is off" do
      account.update!(current_balance: 50)

      result = settle_invoice(total_value: 100)

      expect(result).to be_a(Solid::Failure)
      expect(result.type).to eq(:insufficient_account_balance)
      expect(account.reload.current_balance).to eq(BigDecimal("50"))
      expect(credit_card.reload.available_limit).to eq(BigDecimal("2000"))
      expect(CreditCard::InvoiceSettlement::Record.count).to eq(0)
    end
  end

  describe "facade" do
    it "is callable as CreditCard.settle_invoice" do
      result = CreditCard.settle_invoice(
        user: user_entity,
        credit_card_id: credit_card.id,
        payment_account_id: account.id,
        opening_date: Date.new(2026, 7, 11),
        closing_date: Date.new(2026, 8, 10),
        due_date: Date.new(2026, 8, 17),
        total_value: 100,
        settled_on: Date.new(2026, 8, 17)
      )

      expect(result).to be_a(Solid::Success)
      expect(result.type).to eq(:credit_card_invoice_settled)
    end
  end
end
