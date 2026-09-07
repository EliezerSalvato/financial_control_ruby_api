require "rails_helper"

RSpec.describe Core::MonthlyStatus::Closing do
  include ActiveSupport::Testing::TimeHelpers

  let(:user) { create(:user, :verified) }
  let(:month) { 8 }
  let(:year) { 2026 }

  around { |example| travel_to(Date.new(2026, 9, 1), &example) }

  def close(**overrides)
    described_class.call(user_id: user.id, month:, year:, **overrides)
  end

  def settle_account(transaction_record, occurred_on:)
    create(
      :transaction_settlement,
      :for_account,
      financial_transaction: transaction_record,
      occurred_on:,
      value: 100
    )
  end

  def settle_transfer(transaction_record, occurred_on:)
    create(
      :transaction_settlement,
      :for_transfer,
      financial_transaction: transaction_record,
      occurred_on:,
      value: 100
    )
  end

  def settle_credit_card(transaction_record, occurred_on:)
    create(
      :transaction_settlement,
      :for_credit_card,
      financial_transaction: transaction_record,
      occurred_on:,
      value: 100
    )
  end

  describe "a fully settled month" do
    it "closes when every account/transfer occurrence is settled and invoices are paid" do
      create(:monthly_status, user:, month:, year:)
      account = create(:account, :bank_account, user:)
      source = create(:account, :bank_account, user:, name: "Source")
      destination = create(:account, :bank_account, user:, name: "Destination")
      credit_card = create(:credit_card, user:, closing_day: 10, due_day: 17)
      account_transaction = create(:transaction, user:, account:, value: 100, starts_on: Date.new(2026, 8, 11))
      transfer = create(
        :transaction,
        :transfer,
        user:,
        source_account: source,
        destination_account: destination,
        value: 100,
        starts_on: Date.new(2026, 8, 11)
      )
      card_transaction = create(
        :transaction,
        :with_credit_card,
        user:,
        credit_card:,
        value: 100,
        starts_on: Date.new(2026, 8, 1)
      )
      settle_account(account_transaction, occurred_on: Date.new(2026, 8, 11))
      settle_transfer(transfer, occurred_on: Date.new(2026, 8, 11))
      settle_credit_card(card_transaction, occurred_on: Date.new(2026, 8, 1))
      create(
        :credit_card_invoice_settlement,
        credit_card:,
        due_date: Date.new(2026, 8, 17)
      )

      result = close

      expect(result).to be_a(Solid::Success)
      expect(result.type).to eq(:monthly_status_closed)
      expect(result.value[:monthly_status]).to have_attributes(
        month:,
        year:,
        status: Core::MonthlyStatus::Status::CLOSED
      )
      expect(MonthlyStatus::Record.find_by!(user_id: user.id, month:, year:).status).to eq("closed")
    end
  end

  describe "pending account occurrence" do
    it "stays open and returns pending_occurrences with the missing transaction_id and occurred_on" do
      create(:monthly_status, user:, month:, year:)
      account = create(:account, :bank_account, user:)
      transaction_record = create(
        :transaction,
        user:,
        account:,
        description: "Unsettled grocery",
        value: 100,
        starts_on: Date.new(2026, 8, 11)
      )

      result = close

      expect(result).to be_a(Solid::Success)
      expect(result.type).to eq(:monthly_status_kept_open)
      expect(result.value[:monthly_status]).to have_attributes(status: Core::MonthlyStatus::Status::OPEN)
      expect(result.value[:pending_occurrences]).to contain_exactly(
        { transaction_id: transaction_record.id, occurred_on: Date.new(2026, 8, 11), description: "Unsettled grocery" }
      )
      expect(result.value[:pending_invoices]).to eq([])
    end
  end

  describe "pending transfer" do
    it "stays open when a transfer is unsettled" do
      create(:monthly_status, user:, month:, year:)
      source = create(:account, :bank_account, user:, name: "Source")
      destination = create(:account, :bank_account, user:, name: "Destination")
      transfer = create(
        :transaction,
        :transfer,
        user:,
        source_account: source,
        destination_account: destination,
        description: "Unsettled transfer",
        value: 100,
        starts_on: Date.new(2026, 8, 11)
      )

      result = close

      expect(result).to be_a(Solid::Success)
      expect(result.type).to eq(:monthly_status_kept_open)
      expect(result.value[:pending_occurrences]).to contain_exactly(
        { transaction_id: transfer.id, occurred_on: Date.new(2026, 8, 11), description: "Unsettled transfer" }
      )
    end
  end

  describe "unpaid invoice" do
    it "stays open and returns pending_invoices" do
      create(:monthly_status, user:, month:, year:)
      credit_card = create(:credit_card, user:, closing_day: 10, due_day: 17)
      create(
        :transaction,
        :with_credit_card,
        user:,
        credit_card:,
        value: 100,
        starts_on: Date.new(2026, 8, 1)
      )

      result = close

      expect(result).to be_a(Solid::Success)
      expect(result.type).to eq(:monthly_status_kept_open)
      expect(result.value[:pending_occurrences]).to eq([])
      expect(result.value[:pending_invoices]).to contain_exactly(
        { credit_card_id: credit_card.id, due_date: Date.new(2026, 8, 17) }
      )
    end

    it "stays open when a card occurrence is settled but the invoice is still unpaid" do
      create(:monthly_status, user:, month:, year:)
      credit_card = create(:credit_card, user:, closing_day: 10, due_day: 17)
      card_transaction = create(
        :transaction,
        :with_credit_card,
        user:,
        credit_card:,
        value: 100,
        starts_on: Date.new(2026, 8, 1)
      )
      settle_credit_card(card_transaction, occurred_on: Date.new(2026, 8, 1))

      result = close

      expect(result).to be_a(Solid::Success)
      expect(result.type).to eq(:monthly_status_kept_open)
      expect(result.value[:pending_invoices]).to contain_exactly(
        { credit_card_id: credit_card.id, due_date: Date.new(2026, 8, 17) }
      )
    end
  end

  describe "a month with no entries" do
    it "closes" do
      create(:monthly_status, user:, month:, year:)

      result = close

      expect(result).to be_a(Solid::Success)
      expect(result.type).to eq(:monthly_status_closed)
      expect(MonthlyStatus::Record.find_by!(user_id: user.id, month:, year:).status).to eq("closed")
    end
  end

  describe "current or future month" do
    it "does not close the current month" do
      create(:monthly_status, user:, month: 9, year: 2026)

      result = close(month: 9)

      expect(result).to be_a(Solid::Failure)
      expect(result.type).to eq(:monthly_status_not_closeable)
      expect(result.value[:input].errors.details[:base]).to include(error: :monthly_status_not_closeable)
      expect(MonthlyStatus::Record.find_by!(user_id: user.id, month: 9, year: 2026).status).to eq("open")
    end

    it "does not close a future month" do
      create(:monthly_status, user:, month: 10, year: 2026)

      result = close(month: 10)

      expect(result).to be_a(Solid::Failure)
      expect(result.type).to eq(:monthly_status_not_closeable)
    end

    it "does not create a row for the current month when missing" do
      expect {
        result = close(month: 9)

        expect(result).to be_a(Solid::Failure)
        expect(result.type).to eq(:monthly_status_not_closeable)
      }.not_to change(MonthlyStatus::Record, :count)
    end
  end

  describe "missing monthly_statuses row" do
    it "creates the row and closes when there are no pending items" do
      result = nil

      expect { result = close }.to change(MonthlyStatus::Record, :count).by(1)

      expect(result).to be_a(Solid::Success)
      expect(result.type).to eq(:monthly_status_closed)
      expect(MonthlyStatus::Record.find_by!(user_id: user.id, month:, year:)).to have_attributes(
        status: "closed"
      )
    end

    it "creates the row and keeps it open when there are pending items" do
      account = create(:account, :bank_account, user:)
      create(:transaction, user:, account:, value: 100, starts_on: Date.new(2026, 8, 11))

      result = nil
      expect { result = close }.to change(MonthlyStatus::Record, :count).by(1)

      expect(result).to be_a(Solid::Success)
      expect(result.type).to eq(:monthly_status_kept_open)
      expect(MonthlyStatus::Record.find_by!(user_id: user.id, month:, year:).status).to eq("open")
    end

    it "does not create a row when a later month is closed" do
      create(:monthly_status, :closed, user:, month: 9, year: 2026)

      result = nil
      expect { result = close }.not_to change(MonthlyStatus::Record, :count)

      expect(result).to be_a(Solid::Failure)
      expect(result.type).to eq(:later_month_closed)
      expect(MonthlyStatus::Record.find_by(user_id: user.id, month:, year:)).to be_nil
    end
  end

  describe "logging" do
    it "never calls Rails.logger" do
      create(:monthly_status, user:, month:, year:)
      allow(Rails.logger).to receive(:info)
      allow(Rails.logger).to receive(:warn)
      allow(Rails.logger).to receive(:error)

      close

      expect(Rails.logger).not_to have_received(:info)
      expect(Rails.logger).not_to have_received(:warn)
      expect(Rails.logger).not_to have_received(:error)
    end
  end

  describe "batch queries" do
    it "uses one settled_keys call and one paid_keys call" do
      create(:monthly_status, user:, month:, year:)
      account = create(:account, :bank_account, user:)
      credit_card = create(:credit_card, user:, closing_day: 10, due_day: 17)
      first = create(:transaction, user:, account:, value: 100, starts_on: Date.new(2026, 8, 5))
      second = create(:transaction, user:, account:, value: 50, starts_on: Date.new(2026, 8, 12))
      create(:transaction, :with_credit_card, user:, credit_card:, value: 80, starts_on: Date.new(2026, 8, 1))
      create(:transaction, :with_credit_card, user:, credit_card:, value: 20, starts_on: Date.new(2026, 8, 2))
      settle_account(first, occurred_on: Date.new(2026, 8, 5))
      settle_account(second, occurred_on: Date.new(2026, 8, 12))

      allow(Transaction::Adapters.settlement_repository).to receive(:settled_keys).and_call_original
      allow(CreditCard::Adapters.invoice_settlement_repository).to receive(:paid_keys).and_call_original

      close

      expect(Transaction::Adapters.settlement_repository).to have_received(:settled_keys).once
      expect(CreditCard::Adapters.invoice_settlement_repository).to have_received(:paid_keys).once
    end
  end
end
