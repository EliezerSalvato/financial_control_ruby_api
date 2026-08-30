require "rails_helper"

RSpec.describe Core::Settlement::Processing do
  include ActiveSupport::Testing::TimeHelpers
  let(:user) { create(:user, :verified) }
  let(:month) { 8 }
  let(:year) { 2026 }
  let(:reference_date) { Date.current.yesterday }
  let!(:monthly_status) { create(:monthly_status, user:, month:, year:) }

  around { |example| travel_to(Date.new(2026, 8, 29), &example) }

  def process(**overrides)
    described_class.call(user_id: user.id, month:, year:, reference_date:, **overrides)
  end

  describe "account income and expense" do
    it "adjusts current_balance" do
      account = create(:account, :bank_account, user:, current_balance: 1000)
      create(:transaction, :income, user:, account:, value: 100, starts_on: Date.new(2026, 8, 11))
      create(:transaction, user:, account:, value: 500, starts_on: Date.new(2026, 8, 11))

      result = process

      expect(result).to be_a(Solid::Success)
      expect(result.type).to eq(:settlements_completed)
      expect(account.reload.current_balance).to eq(BigDecimal("600"))
      expect(result.value[:settled_count]).to eq(2)
      expect(result.value[:failures]).to eq([])
    end
  end

  describe "transfer" do
    it "debits the source and credits the destination" do
      source = create(:account, :bank_account, user:, name: "NuConta", current_balance: 1000)
      destination = create(:account, :bank_account, user:, name: "Poupar", current_balance: 5000)
      create(
        :transaction,
        :transfer,
        user:,
        source_account: source,
        destination_account: destination,
        value: 800,
        starts_on: Date.new(2026, 8, 11)
      )

      result = process

      expect(result).to be_a(Solid::Success)
      expect(source.reload.current_balance).to eq(BigDecimal("200"))
      expect(destination.reload.current_balance).to eq(BigDecimal("5800"))
      expect(result.value[:settled_count]).to eq(1)
    end
  end

  describe "occurrence date" do
    it "does not settle an occurrence with current_recurrence_on after the reference_date" do
      account = create(:account, :bank_account, user:, current_balance: 1000)
      create(:transaction, user:, account:, value: 100, starts_on: Date.current)

      result = process(reference_date: Date.current.yesterday)

      expect(result).to be_a(Solid::Success)
      expect(account.reload.current_balance).to eq(BigDecimal("1000"))
      expect(Transaction::Settlement::Record.count).to eq(0)
      expect(result.value[:settled_count]).to eq(0)
    end
  end

  describe "transaction status" do
    it "does not include completed or canceled transactions" do
      account = create(:account, :bank_account, user:, current_balance: 1000)
      create(:transaction, :completed, user:, account:, value: 100, starts_on: Date.new(2026, 8, 11))
      create(
        :transaction,
        :canceled,
        user:,
        account:,
        value: 200,
        starts_on: Date.new(2026, 8, 11),
        canceled_on: Date.new(2026, 8, 11)
      )

      result = process

      expect(result).to be_a(Solid::Success)
      expect(account.reload.current_balance).to eq(BigDecimal("1000"))
      expect(Transaction::Settlement::Record.count).to eq(0)
    end
  end

  describe "already settled" do
    it "does not settle an already-settled occurrence again" do
      account = create(:account, :bank_account, user:, current_balance: 1000)
      transaction_record = create(:transaction, user:, account:, value: 100, starts_on: Date.new(2026, 8, 11))
      create(
        :transaction_settlement,
        :for_account,
        financial_transaction: transaction_record,
        occurred_on: Date.new(2026, 8, 11),
        value: 100
      )

      allow(Core::Transaction::Settlement::Creation).to receive(:call).and_call_original

      result = process

      expect(result).to be_a(Solid::Success)
      expect(Core::Transaction::Settlement::Creation).not_to have_received(:call)
      expect(account.reload.current_balance).to eq(BigDecimal("1000"))
      expect(Transaction::Settlement::Record.where(transaction_id: transaction_record.id).count).to eq(1)
    end
  end

  describe "credit card" do
    it "consumes limit on the occurrence and, with an invoice due in the month, debits the default_payment_account and releases the limit" do
      account = create(:account, :bank_account, user:, current_balance: 1000)
      credit_card = create(
        :credit_card,
        user:,
        default_payment_account: account,
        total_limit: 5000,
        available_limit: 2000,
        closing_day: 10,
        due_day: 17
      )
      create(:transaction, :with_credit_card, user:, credit_card:, value: 300, starts_on: Date.new(2026, 8, 1))

      result = process

      expect(result).to be_a(Solid::Success)
      expect(result.value[:settled_count]).to eq(1)
      expect(result.value[:invoices_count]).to eq(1)
      expect(account.reload.current_balance).to eq(BigDecimal("700"))
      expect(credit_card.reload.available_limit).to eq(BigDecimal("2000"))
      expect(CreditCard::InvoiceSettlement::Record.count).to eq(1)
    end

    it "consumes limit before paying the invoice so the invoice sums the cycle rows recorded in the same run" do
      account = create(:account, :bank_account, user:, current_balance: 1000)
      credit_card = create(
        :credit_card,
        user:,
        default_payment_account: account,
        total_limit: 5000,
        available_limit: 2000,
        closing_day: 10,
        due_day: 17
      )
      create(:transaction, :with_credit_card, user:, credit_card:, value: 120, starts_on: Date.new(2026, 8, 1))
      create(:transaction, :with_credit_card, user:, credit_card:, value: 80, starts_on: Date.new(2026, 8, 2))

      result = process

      expect(result).to be_a(Solid::Success)
      expect(CreditCard::InvoiceSettlement::Record.sole.total_value).to eq(200)
      expect(account.reload.current_balance).to eq(BigDecimal("800"))
      expect(credit_card.reload.available_limit).to eq(BigDecimal("2000"))
    end
  end

  describe "idempotency" do
    it "does not duplicate effects when running twice" do
      account = create(:account, :bank_account, user:, current_balance: 1000)
      create(:transaction, user:, account:, value: 100, starts_on: Date.new(2026, 8, 11))

      first = process
      second = process

      expect(first).to be_a(Solid::Success)
      expect(second).to be_a(Solid::Success)
      expect(account.reload.current_balance).to eq(BigDecimal("900"))
      expect(Transaction::Settlement::Record.count).to eq(1)
    end
  end

  describe "insufficient funds" do
    it "skips the failing item, continues with the others, and exposes failures with type and identity" do
      healthy_account = create(:account, :bank_account, user:, name: "Healthy", current_balance: 1000)
      broke_account = create(:account, :bank_account, user:, name: "Broke", current_balance: 10)
      credit_card = create(:credit_card, user:, total_limit: 5000, available_limit: 50)
      healthy = create(:transaction, user:, account: healthy_account, value: 100, starts_on: Date.new(2026, 8, 11))
      broke = create(:transaction, user:, account: broke_account, value: 500, starts_on: Date.new(2026, 8, 11))
      card = create(:transaction, :with_credit_card, user:, credit_card:, value: 300, starts_on: Date.new(2026, 8, 1))

      result = process

      expect(result).to be_a(Solid::Success)
      expect(healthy_account.reload.current_balance).to eq(BigDecimal("900"))
      expect(broke_account.reload.current_balance).to eq(BigDecimal("10"))
      expect(credit_card.reload.available_limit).to eq(BigDecimal("50"))
      expect(Transaction::Settlement::Record.where(transaction_id: healthy.id).count).to eq(1)
      expect(Transaction::Settlement::Record.where(transaction_id: [ broke.id, card.id ]).count).to eq(0)
      expect(result.value[:failures]).to contain_exactly(
        a_hash_including(
          kind: :occurrence,
          transaction_id: broke.id,
          occurred_on: Date.new(2026, 8, 11),
          type: :insufficient_account_balance
        ),
        a_hash_including(
          kind: :occurrence,
          transaction_id: card.id,
          occurred_on: Date.new(2026, 8, 1),
          type: :insufficient_available_limit
        )
      )
      expect(result.value[:failures]).to all(include(:messages))
    end

    it "records an invoice payment failure without blocking other items" do
      healthy_account = create(:account, :bank_account, user:, name: "Healthy", current_balance: 1000)
      broke_account = create(:account, :bank_account, user:, name: "Broke", current_balance: 10)
      credit_card = create(
        :credit_card,
        user:,
        default_payment_account: broke_account,
        total_limit: 5000,
        available_limit: 2000,
        closing_day: 10,
        due_day: 17
      )
      create(:transaction, user:, account: healthy_account, value: 100, starts_on: Date.new(2026, 8, 11))
      create(:transaction, :with_credit_card, user:, credit_card:, value: 300, starts_on: Date.new(2026, 8, 1))

      result = process

      expect(result).to be_a(Solid::Success)
      expect(healthy_account.reload.current_balance).to eq(BigDecimal("900"))
      expect(broke_account.reload.current_balance).to eq(BigDecimal("10"))
      expect(credit_card.reload.available_limit).to eq(BigDecimal("1700"))
      expect(result.value[:settled_count]).to eq(2)
      expect(result.value[:invoices_count]).to eq(0)
      expect(CreditCard::InvoiceSettlement::Record.count).to eq(0)
      expect(result.value[:failures]).to contain_exactly(
        a_hash_including(
          kind: :invoice,
          credit_card_id: credit_card.id,
          due_date: Date.new(2026, 8, 17),
          type: :insufficient_account_balance
        )
      )
    end

    it "settles even when the result is negative if the flags are on" do
      account = create(:account, :bank_account, :allow_negative_balance, user:, current_balance: 10)
      credit_card = create(
        :credit_card,
        :allow_negative_available_limit,
        user:,
        total_limit: 5000,
        available_limit: 50,
        due_day: 31
      )
      create(:transaction, user:, account:, value: 100, starts_on: Date.new(2026, 8, 11))
      create(:transaction, :with_credit_card, user:, credit_card:, value: 300, starts_on: Date.new(2026, 8, 1))

      result = process

      expect(result).to be_a(Solid::Success)
      expect(result.value[:failures]).to eq([])
      expect(account.reload.current_balance).to eq(BigDecimal("-90"))
      expect(credit_card.reload.available_limit).to eq(BigDecimal("-250"))
    end
  end

  describe "inactive resources" do
    it "settles an occurrence on an inactive account or card the same as an active resource" do
      account = create(:account, :bank_account, :inactive, user:, current_balance: 1000)
      credit_card = create(:credit_card, :inactive, user:, total_limit: 5000, available_limit: 2000, due_day: 31)
      create(:transaction, user:, account:, value: 100, starts_on: Date.new(2026, 8, 11))
      create(:transaction, :with_credit_card, user:, credit_card:, value: 150, starts_on: Date.new(2026, 8, 1))

      result = process

      expect(result).to be_a(Solid::Success)
      expect(account.reload.current_balance).to eq(BigDecimal("900"))
      expect(credit_card.reload.available_limit).to eq(BigDecimal("1850"))
    end
  end

  describe "logging" do
    it "never calls Rails.logger" do
      account = create(:account, :bank_account, user:, current_balance: 1000)
      create(:transaction, user:, account:, value: 100, starts_on: Date.new(2026, 8, 11))

      allow(Rails.logger).to receive(:info)
      allow(Rails.logger).to receive(:warn)
      allow(Rails.logger).to receive(:error)

      process

      expect(Rails.logger).not_to have_received(:info)
      expect(Rails.logger).not_to have_received(:warn)
      expect(Rails.logger).not_to have_received(:error)
    end
  end

  describe "reference_date" do
    it "rejects a date that is not today or yesterday in the current month" do
      result = process(reference_date: Date.new(2026, 8, 20))

      expect(result).to be_a(Solid::Failure)
      expect(result.type).to eq(:invalid_input)
      expect(result.value[:input].errors[:reference_date]).to eq([ "must be today or yesterday" ])
      expect(Transaction::Settlement::Record.count).to eq(0)
    end

    it "accepts today as reference_date in the current month" do
      account = create(:account, :bank_account, user:, current_balance: 1000)
      create(:transaction, user:, account:, value: 100, starts_on: Date.new(2026, 8, 11))

      result = process(reference_date: Date.current)

      expect(result).to be_a(Solid::Success)
      expect(account.reload.current_balance).to eq(BigDecimal("900"))
    end

    it "accepts yesterday as reference_date in the current month" do
      account = create(:account, :bank_account, user:, current_balance: 1000)
      create(:transaction, user:, account:, value: 100, starts_on: Date.new(2026, 8, 11))

      result = process(reference_date: Date.current.yesterday)

      expect(result).to be_a(Solid::Success)
      expect(account.reload.current_balance).to eq(BigDecimal("900"))
    end

    it "ignores the given reference_date and uses the last day of a past month" do
      account = create(:account, :bank_account, user:, current_balance: 1000)
      create(:transaction, user:, account:, value: 100, starts_on: Date.new(2026, 7, 20))
      create(:monthly_status, user:, month: 7, year: 2026)

      result = process(month: 7, year: 2026, reference_date: Date.new(2026, 7, 10))

      expect(result).to be_a(Solid::Success)
      expect(account.reload.current_balance).to eq(BigDecimal("900"))
      expect(Transaction::Settlement::Record.sole.occurred_on).to eq(Date.new(2026, 7, 20))
    end

    it "settles a credit card occurrence and invoice in a past month" do
      account = create(:account, :bank_account, user:, current_balance: 1000)
      credit_card = create(
        :credit_card,
        user:,
        default_payment_account: account,
        total_limit: 5000,
        available_limit: 5000,
        closing_day: 10,
        due_day: 17
      )
      create(:transaction, :with_credit_card, user:, credit_card:, value: 300, starts_on: Date.new(2026, 7, 1))
      create(:monthly_status, user:, month: 7, year: 2026)

      result = process(month: 7, year: 2026, reference_date: Date.new(2026, 7, 10))

      expect(result).to be_a(Solid::Success)
      expect(result.value[:failures]).to eq([])
      expect(result.value[:settled_count]).to eq(1)
      expect(result.value[:invoices_count]).to eq(1)
      expect(account.reload.current_balance).to eq(BigDecimal("700"))
      expect(credit_card.reload.available_limit).to eq(BigDecimal("5000"))
    end

    it "pays past-month invoices for later upfront installments without exceeding total_limit" do
      account = create(:account, :bank_account, user:, current_balance: 5000)
      first_card = create(
        :credit_card,
        user:,
        default_payment_account: account,
        name: "Card A",
        total_limit: 5000,
        available_limit: 5000,
        closing_day: 10,
        due_day: 17
      )
      second_card = create(
        :credit_card,
        user:,
        default_payment_account: account,
        name: "Card B",
        total_limit: 5000,
        available_limit: 5000,
        closing_day: 10,
        due_day: 17
      )
      create(
        :transaction,
        :with_credit_card,
        :installment,
        user:,
        credit_card: first_card,
        value: 300,
        starts_on: Date.new(2026, 6, 1),
        installments_count: 3,
        ends_on: Date.new(2026, 8, 1)
      )
      create(
        :transaction,
        :with_credit_card,
        :installment,
        user:,
        credit_card: second_card,
        value: 200,
        starts_on: Date.new(2026, 6, 1),
        installments_count: 3,
        ends_on: Date.new(2026, 8, 1)
      )
      create(:monthly_status, user:, month: 7, year: 2026)

      result = process(month: 7, year: 2026, reference_date: Date.new(2026, 7, 10))

      expect(result).to be_a(Solid::Success)
      expect(result.value[:failures]).to eq([])
      expect(result.value[:settled_count]).to eq(2)
      expect(result.value[:invoices_count]).to eq(2)
      expect(account.reload.current_balance).to eq(BigDecimal("4500"))
      expect(first_card.reload.available_limit).to eq(BigDecimal("5000"))
      expect(second_card.reload.available_limit).to eq(BigDecimal("5000"))
    end

    it "rejects a future month" do
      create(:monthly_status, user:, month: 9, year: 2026)

      result = process(month: 9, year: 2026, reference_date: Date.current)

      expect(result).to be_a(Solid::Failure)
      expect(result.type).to eq(:invalid_input)
      expect(result.value[:input].errors[:month]).to eq([ "cannot be in the future" ])
    end
  end

  describe "monthly status processing flags" do
    it "sets processing true then false and stamps last_processed_at when the run completes" do
      account = create(:account, :bank_account, user:, current_balance: 1000)
      create(:transaction, user:, account:, value: 100, starts_on: Date.new(2026, 8, 11))
      attributes_seen = []

      allow(MonthlyStatus::Repository::Adapters::ActiveRecord).to receive(:update).and_wrap_original do |method, **kwargs|
        attributes_seen << kwargs[:attributes]
        method.call(**kwargs)
      end

      result = process

      expect(result).to be_a(Solid::Success)
      expect(attributes_seen).to eq([
        { processing: true },
        { processing: false, last_processed_at: Time.current }
      ])
      monthly_status.reload
      expect(monthly_status.processing).to eq(false)
      expect(monthly_status.last_processed_at).to eq(Time.current)
    end

    it "returns Failure when the monthly status is missing" do
      monthly_status.destroy!

      result = process

      expect(result).to be_a(Solid::Failure)
      expect(result.type).to eq(:monthly_status_not_found)
      expect(Transaction::Settlement::Record.count).to eq(0)
    end

    it "returns Failure when the monthly status update fails" do
      allow(MonthlyStatus::Repository::Adapters::ActiveRecord).to receive(:update).and_return(
        Solid::Failure(:monthly_status_update_failed, errors: Core::Errors.new(status: [ "invalid" ]))
      )

      result = process

      expect(result).to be_a(Solid::Failure)
      expect(result.type).to eq(:monthly_status_update_failed)
      expect(result.value[:input].errors[:base]).to include("Monthly status update failed")
      expect(monthly_status.reload.processing).to eq(false)
    end
  end

  describe "previous month" do
    it "rejects processing when the previous month is still open" do
      create(:monthly_status, user:, month: 7, year: 2026)

      result = process

      expect(result).to be_a(Solid::Failure)
      expect(result.type).to eq(:previous_month_open)
      expect(result.value[:input].errors[:base]).to eq([
        "The previous month must be closed before processing this month"
      ])
      expect(monthly_status.reload.processing).to eq(false)
      expect(Transaction::Settlement::Record.count).to eq(0)
    end

    it "starts processing when the previous month is closed" do
      create(:monthly_status, :closed, user:, month: 7, year: 2026)

      result = process

      expect(result).to be_a(Solid::Success)
      expect(monthly_status.reload.processing).to eq(false)
    end

    it "starts processing when the previous month has no monthly status" do
      result = process

      expect(result).to be_a(Solid::Success)
    end

    it "rejects processing when the previous year-end month is still open" do
      create(:monthly_status, user:, month: 1, year: 2026)
      create(:monthly_status, user:, month: 12, year: 2025)

      result = process(month: 1, year: 2026, reference_date: Date.new(2026, 1, 31))

      expect(result).to be_a(Solid::Failure)
      expect(result.type).to eq(:previous_month_open)
    end

    it "does not treat another user's open previous month as a blocker" do
      other_user = create(:user, :verified)
      create(:monthly_status, user: other_user, month: 7, year: 2026)

      result = process

      expect(result).to be_a(Solid::Success)
    end
  end

  describe "later closed month" do
    it "rejects processing when a later month is closed" do
      create(:monthly_status, :closed, user:, month: 9, year: 2026)

      result = process

      expect(result).to be_a(Solid::Failure)
      expect(result.type).to eq(:later_month_closed)
      expect(result.value[:input].errors[:base]).to eq([ "A later month is already closed" ])
      expect(monthly_status.reload.processing).to eq(false)
      expect(Transaction::Settlement::Record.count).to eq(0)
    end

    it "rejects processing when a later month in the next year is closed" do
      create(:monthly_status, user:, month: 12, year: 2025)
      create(:monthly_status, :closed, user:, month: 1, year: 2026)

      result = process(month: 12, year: 2025, reference_date: Date.new(2025, 12, 31))

      expect(result).to be_a(Solid::Failure)
      expect(result.type).to eq(:later_month_closed)
    end

    it "starts processing when only earlier months are closed" do
      create(:monthly_status, :closed, user:, month: 6, year: 2026)

      result = process

      expect(result).to be_a(Solid::Success)
    end

    it "does not treat another user's later closed month as a blocker" do
      other_user = create(:user, :verified)
      create(:monthly_status, :closed, user: other_user, month: 9, year: 2026)

      result = process

      expect(result).to be_a(Solid::Success)
    end
  end

  describe "facade" do
    it "is callable as Settlement.process" do
      result = Settlement.process(user_id: user.id, month:, year:, reference_date:)

      expect(result).to be_a(Solid::Success)
      expect(result.type).to eq(:settlements_completed)
    end
  end
end
