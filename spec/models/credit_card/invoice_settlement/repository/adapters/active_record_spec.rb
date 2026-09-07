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
          credit_card_name: credit_card.name,
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
          credit_card_name: same_month_card.name,
          opening_date: Date.new(2026, 7, 11),
          closing_date: Date.new(2026, 8, 10),
          due_date: Date.new(2026, 8, 17),
          total_value: 80
        ),
        have_attributes(
          credit_card_id: previous_month_card.id,
          credit_card_name: previous_month_card.name,
          opening_date: Date.new(2026, 6, 26),
          closing_date: Date.new(2026, 7, 25),
          due_date: Date.new(2026, 8, 10),
          total_value: 120
        )
      )
    end
  end

  describe "#create" do
    def create_invoice(**overrides)
      repository.create(
        credit_card_id: credit_card.id,
        payment_account_id: account.id,
        opening_date: Date.new(2026, 7, 11),
        closing_date: Date.new(2026, 8, 10),
        due_date: Date.new(2026, 8, 17),
        total_value: 100,
        released_limit: 100,
        settled_on: Date.new(2026, 8, 17),
        **overrides
      )
    end

    it "returns Success(:already_settled) on a duplicate (credit_card_id, due_date)" do
      first = create_invoice
      second = nil

      expect { second = create_invoice(total_value: 50, released_limit: 50) }.not_to raise_error

      expect(second).to be_a(Solid::Success)
      expect(second.type).to eq(:already_settled)
      expect(second.value[:invoice_settlement]).to have_attributes(
        id: first.value[:invoice_settlement].id,
        total_value: 100,
        due_date: Date.new(2026, 8, 17)
      )
      expect(CreditCard::InvoiceSettlement::Record.count).to eq(1)
    end
  end

  describe "#link_occurrences" do
    it "links only still-unlinked rows of that cycle and card" do
      in_cycle = create(:transaction, :with_credit_card, user:, credit_card:, starts_on: Date.new(2026, 8, 1), value: 100)
      already_linked = create(:transaction, :with_credit_card, user:, credit_card:, starts_on: Date.new(2026, 8, 2), value: 50)
      outside_cycle = create(:transaction, :with_credit_card, user:, credit_card:, starts_on: Date.new(2026, 8, 15), value: 80)
      other_card = create(:credit_card, user:, default_payment_account: account, closing_day: 10, due_day: 17)
      other_card_transaction = create(:transaction, :with_credit_card, user:, credit_card: other_card, starts_on: Date.new(2026, 8, 1), value: 70)

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
      unlinked_settlement = settle_card_occurrence(in_cycle, occurred_on: Date.new(2026, 8, 1), value: 100)
      linked_settlement = settle_card_occurrence(already_linked, occurred_on: Date.new(2026, 8, 2), value: 50, invoice: previous_invoice)
      outside_settlement = settle_card_occurrence(outside_cycle, occurred_on: Date.new(2026, 8, 15), value: 80)
      other_card_settlement = settle_card_occurrence(other_card_transaction, occurred_on: Date.new(2026, 8, 1), value: 70)

      invoice = create(
        :credit_card_invoice_settlement,
        credit_card:,
        payment_account: account,
        opening_date: Date.new(2026, 7, 11),
        closing_date: Date.new(2026, 8, 10),
        due_date: Date.new(2026, 8, 17),
        total_value: 100,
        settled_on: Date.new(2026, 8, 17)
      )

      result = repository.link_occurrences(invoice_settlement: CreditCard::InvoiceSettlement::Mapper.to_entity(invoice))

      expect(result).to be_a(Solid::Success)
      expect(result.type).to eq(:credit_card_invoice_occurrences_linked)
      expect(result.value[:linked_count]).to eq(1)
      expect(unlinked_settlement.for_credit_card.reload.credit_card_invoice_settlement_id).to eq(invoice.id)
      expect(linked_settlement.for_credit_card.reload.credit_card_invoice_settlement_id).to eq(previous_invoice.id)
      expect(outside_settlement.for_credit_card.reload.credit_card_invoice_settlement_id).to be_nil
      expect(other_card_settlement.for_credit_card.reload.credit_card_invoice_settlement_id).to be_nil
    end
  end

  describe "#paid_keys" do
    it "filters by card and due_date" do
      matching = create(
        :credit_card_invoice_settlement,
        credit_card:,
        payment_account: account,
        due_date: Date.new(2026, 8, 17)
      )
      other_due = create(
        :credit_card_invoice_settlement,
        credit_card:,
        payment_account: account,
        opening_date: Date.new(2026, 8, 11),
        closing_date: Date.new(2026, 9, 10),
        due_date: Date.new(2026, 9, 17)
      )
      other_card = create(:credit_card, user:, default_payment_account: account, closing_day: 10, due_day: 17)
      other_card_invoice = create(
        :credit_card_invoice_settlement,
        credit_card: other_card,
        payment_account: account,
        due_date: Date.new(2026, 8, 17)
      )

      result = repository.paid_keys(
        credit_card_ids: [ credit_card.id ],
        due_dates: [ Date.new(2026, 8, 17) ]
      )

      expect(result).to be_a(Solid::Success)
      expect(result.type).to eq(:credit_card_invoice_settlements_listed)
      expect(result.value[:keys]).to eq([ [ credit_card.id, Date.new(2026, 8, 17) ] ])
      expect(result.value[:keys]).not_to include([ credit_card.id, other_due.due_date ])
      expect(result.value[:keys]).not_to include([ other_card.id, other_card_invoice.due_date ])
      expect(matching).to be_present
    end
  end

  describe "#paid_covering?" do
    let!(:invoice) do
      create(
        :credit_card_invoice_settlement,
        credit_card:,
        payment_account: account,
        opening_date: Date.new(2026, 7, 11),
        closing_date: Date.new(2026, 8, 10),
        due_date: Date.new(2026, 8, 17)
      )
    end

    it "is true when from/to sit inside the paid cycle" do
      expect(repository.paid_covering?(credit_card_id: credit_card.id, from: Date.new(2026, 8, 1), to: Date.new(2026, 8, 1))).to be(true)
    end

    it "is true on the opening and closing dates" do
      expect(repository.paid_covering?(credit_card_id: credit_card.id, from: Date.new(2026, 7, 11), to: Date.new(2026, 7, 11))).to be(true)
      expect(repository.paid_covering?(credit_card_id: credit_card.id, from: Date.new(2026, 8, 10), to: Date.new(2026, 8, 10))).to be(true)
    end

    it "is true when the range overlaps the paid cycle even if from is outside" do
      expect(
        repository.paid_covering?(
          credit_card_id: credit_card.id,
          from: Date.new(2026, 7, 5),
          to: Date.new(2026, 9, 5)
        )
      ).to be(true)
    end

    it "is true for an open-ended range that starts before the paid closing date" do
      expect(repository.paid_covering?(credit_card_id: credit_card.id, from: Date.new(2026, 7, 5), to: nil)).to be(true)
    end

    it "is false when the period is after the paid cycle" do
      expect(repository.paid_covering?(credit_card_id: credit_card.id, from: Date.new(2026, 8, 11), to: Date.new(2026, 8, 11))).to be(false)
    end

    it "is false when the period is before the paid cycle" do
      expect(repository.paid_covering?(credit_card_id: credit_card.id, from: Date.new(2026, 7, 10), to: Date.new(2026, 7, 10))).to be(false)
    end

    it "is false for another card" do
      other_card = create(:credit_card, user:, default_payment_account: account, closing_day: 10, due_day: 17)

      expect(repository.paid_covering?(credit_card_id: other_card.id, from: Date.new(2026, 8, 1), to: Date.new(2026, 8, 1))).to be(false)
      expect(invoice).to be_present
    end
  end
end
