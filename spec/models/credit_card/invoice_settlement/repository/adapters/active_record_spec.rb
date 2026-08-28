require "rails_helper"

RSpec.describe CreditCard::InvoiceSettlement::Repository::Adapters::ActiveRecord do
  subject(:repository) { described_class }

  let(:user) { create(:user, :verified) }
  let(:account) { create(:account, :bank_account, user:) }
  let(:credit_card) do
    create(:credit_card, user:, default_payment_account: account, closing_day: 10, due_day: 17)
  end

  def list_due(user_id: user.id, month: 8, year: 2026, reference_date: Date.new(2026, 8, 17))
    repository.list_due(user_id:, month:, year:, reference_date:)
  end

  def due_invoices
    list_due.value.fetch(:due_invoices)
  end

  def settle_card_occurrence(transaction, occurred_on:, value:, invoice: nil)
    settlement = create(
      :transaction_settlement,
      :for_credit_card,
      financial_transaction: transaction,
      occurred_on:,
      settled_on: occurred_on,
      value:
    )
    settlement.for_credit_card.update!(credit_card_invoice_settlement: invoice) if invoice
    settlement
  end

  describe "#list_due" do
    it "sums cycle occurrences whose credit-card has_one has credit_card_invoice_settlement_id IS NULL" do
      first = create(:transaction, :with_credit_card, user:, credit_card:, starts_on: Date.new(2026, 8, 1), value: 100)
      second = create(:transaction, :with_credit_card, user:, credit_card:, starts_on: Date.new(2026, 8, 2), value: 50)
      outside = create(:transaction, :with_credit_card, user:, credit_card:, starts_on: Date.new(2026, 8, 15), value: 999)
      settle_card_occurrence(first, occurred_on: Date.new(2026, 8, 1), value: 100)
      settle_card_occurrence(second, occurred_on: Date.new(2026, 8, 2), value: 50)
      settle_card_occurrence(outside, occurred_on: Date.new(2026, 8, 15), value: 999)

      result = list_due

      expect(result).to be_a(Solid::Success)
      expect(result.type).to eq(:credit_card_due_invoices_listed)
      expect(result.value[:due_invoices]).to contain_exactly(
        have_attributes(
          credit_card_id: credit_card.id,
          payment_account_id: account.id,
          opening_date: Date.new(2026, 7, 11),
          closing_date: Date.new(2026, 8, 10),
          due_date: Date.new(2026, 8, 17),
          total_value: 150
        )
      )
      expect(result.value[:due_invoices].sole).to be_a(Core::CreditCard::InvoiceSettlement::Due)
    end

    it "excludes an occurrence already linked to an invoice from the sum" do
      unlinked = create(:transaction, :with_credit_card, user:, credit_card:, starts_on: Date.new(2026, 8, 1), value: 100)
      linked = create(:transaction, :with_credit_card, user:, credit_card:, starts_on: Date.new(2026, 8, 2), value: 50)
      previous_invoice = create(
        :credit_card_invoice_settlement,
        credit_card:,
        payment_account: account,
        opening_date: Date.new(2026, 6, 11),
        closing_date: Date.new(2026, 7, 10),
        due_date: Date.new(2026, 7, 17),
        total_value: 50,
        settled_on: Date.new(2026, 7, 17)
      )
      settle_card_occurrence(unlinked, occurred_on: Date.new(2026, 8, 1), value: 100)
      settle_card_occurrence(linked, occurred_on: Date.new(2026, 8, 2), value: 50, invoice: previous_invoice)

      expect(due_invoices.sole).to have_attributes(credit_card_id: credit_card.id, total_value: 100)
    end

    it "does not return a cycle with no movement" do
      create(:credit_card, user:, default_payment_account: account, closing_day: 10, due_day: 17)

      expect(due_invoices).to eq([])
    end

    it "does not return a cycle that already has a paid invoice" do
      transaction = create(:transaction, :with_credit_card, user:, credit_card:, starts_on: Date.new(2026, 8, 1), value: 100)
      settle_card_occurrence(transaction, occurred_on: Date.new(2026, 8, 1), value: 100)
      create(
        :credit_card_invoice_settlement,
        credit_card:,
        payment_account: account,
        opening_date: Date.new(2026, 7, 11),
        closing_date: Date.new(2026, 8, 10),
        due_date: Date.new(2026, 8, 17),
        total_value: 100,
        settled_on: Date.new(2026, 8, 17)
      )

      expect(due_invoices).to eq([])
    end

    it "does not return a cycle whose due_date is after the reference_date" do
      transaction = create(:transaction, :with_credit_card, user:, credit_card:, starts_on: Date.new(2026, 8, 1), value: 100)
      settle_card_occurrence(transaction, occurred_on: Date.new(2026, 8, 1), value: 100)

      result = list_due(reference_date: Date.new(2026, 8, 16))

      expect(result.value[:due_invoices]).to eq([])
    end

    it "does not return another user's card" do
      transaction = create(:transaction, :with_credit_card, user:, credit_card:, starts_on: Date.new(2026, 8, 1), value: 100)
      settle_card_occurrence(transaction, occurred_on: Date.new(2026, 8, 1), value: 100)

      other_user = create(:user, :verified)
      other_account = create(:account, :bank_account, user: other_user)
      other_card = create(:credit_card, user: other_user, default_payment_account: other_account, closing_day: 10, due_day: 17)
      other_transaction = create(
        :transaction,
        :with_credit_card,
        user: other_user,
        credit_card: other_card,
        starts_on: Date.new(2026, 8, 1),
        value: 200
      )
      settle_card_occurrence(other_transaction, occurred_on: Date.new(2026, 8, 1), value: 200)

      expect(due_invoices.map(&:credit_card_id)).to eq([ credit_card.id ])
    end

    it "covers both cycle shapes (closing_day greater than due_day and closing_day less than due_day)" do
      same_month_card = credit_card
      previous_month_card = create(
        :credit_card,
        user:,
        default_payment_account: account,
        closing_day: 25,
        due_day: 10
      )
      same_month_transaction = create(
        :transaction,
        :with_credit_card,
        user:,
        credit_card: same_month_card,
        starts_on: Date.new(2026, 8, 1),
        value: 80
      )
      previous_month_transaction = create(
        :transaction,
        :with_credit_card,
        user:,
        credit_card: previous_month_card,
        starts_on: Date.new(2026, 7, 10),
        value: 120
      )
      settle_card_occurrence(same_month_transaction, occurred_on: Date.new(2026, 8, 1), value: 80)
      settle_card_occurrence(previous_month_transaction, occurred_on: Date.new(2026, 7, 10), value: 120)

      expect(due_invoices).to contain_exactly(
        have_attributes(
          credit_card_id: same_month_card.id,
          opening_date: Date.new(2026, 7, 11),
          closing_date: Date.new(2026, 8, 10),
          due_date: Date.new(2026, 8, 17),
          total_value: 80
        ),
        have_attributes(
          credit_card_id: previous_month_card.id,
          opening_date: Date.new(2026, 6, 26),
          closing_date: Date.new(2026, 7, 25),
          due_date: Date.new(2026, 8, 10),
          total_value: 120
        )
      )
    end
  end
end
