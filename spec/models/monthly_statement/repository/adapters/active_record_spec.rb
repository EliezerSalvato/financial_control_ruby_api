require "rails_helper"

RSpec.describe MonthlyStatement::Repository::Adapters::ActiveRecord do
  subject(:repository) { described_class }

  let(:user) { create(:user, :verified) }
  let(:account) { create(:account, user:, name: "Checking") }
  let(:credit_card) { create(:credit_card, user:, name: "Nubank", closing_day: 10, due_day: 17) }
  let(:source_account) { create(:account, user:, name: "Checking") }
  let(:destination_account) { create(:account, user:, name: "Savings") }

  def list(**filters)
    repository.list(user_id: user.id, month: 8, year: 2026, **filters)
  end

  def list_transfers(**filters)
    repository.list_transfers(user_id: user.id, month: 8, year: 2026, **filters)
  end

  def listed_ids(result, key: :monthly_statements)
    result.value.fetch(key).map(&:id)
  end

  describe "#list" do
    it "returns the same rows with no filters as the current unfiltered listing" do
      pending_account = create(:transaction, user:, account:, description: "Pending rent", starts_on: Date.new(2026, 8, 11))
      active_card = create(:transaction, :with_credit_card, :active, user:, credit_card:, description: "Active grocery", starts_on: Date.new(2026, 8, 1))
      completed_account = create(:transaction, :completed, user:, account:, description: "Completed bill", starts_on: Date.new(2026, 8, 12))
      canceled_card = create(
        :transaction,
        :with_credit_card,
        :canceled,
        user:,
        credit_card:,
        description: "Canceled purchase",
        starts_on: Date.new(2026, 8, 1),
        canceled_on: Date.new(2026, 8, 15)
      )

      result = list

      expect(result).to be_a(Solid::Success)
      expect(result.type).to eq(:monthly_statements_listed)
      expect(listed_ids(result)).to contain_exactly(
        pending_account.id,
        active_card.id,
        completed_account.id,
        canceled_card.id
      )
    end

    it "excludes completed and canceled transactions when statuses is pending and active" do
      pending_account = create(:transaction, user:, account:, description: "Pending rent", starts_on: Date.new(2026, 8, 11))
      active_card = create(:transaction, :with_credit_card, :active, user:, credit_card:, description: "Active grocery", starts_on: Date.new(2026, 8, 1))
      create(:transaction, :completed, user:, account:, description: "Completed bill", starts_on: Date.new(2026, 8, 12))
      create(
        :transaction,
        :with_credit_card,
        :canceled,
        user:,
        credit_card:,
        description: "Canceled purchase",
        starts_on: Date.new(2026, 8, 1),
        canceled_on: Date.new(2026, 8, 15)
      )

      result = list(statuses: %w[pending active])

      expect(result).to be_a(Solid::Success)
      expect(listed_ids(result)).to contain_exactly(pending_account.id, active_card.id)
    end

    it "returns only occurrences with current_recurrence_on on or before on" do
      included_account = create(:transaction, user:, account:, description: "Early rent", starts_on: Date.new(2026, 8, 5))
      create(:transaction, user:, account:, description: "Late rent", starts_on: Date.new(2026, 8, 20))
      included_card = create(:transaction, :with_credit_card, user:, credit_card:, description: "Early grocery", starts_on: Date.new(2026, 8, 1))

      result = list(on: Date.new(2026, 8, 10))

      expect(result).to be_a(Solid::Success)
      expect(listed_ids(result)).to contain_exactly(included_account.id, included_card.id)
    end

    it "treats explicit statuses: nil and on: nil as omitting the filters" do
      pending_account = create(:transaction, user:, account:, description: "Pending rent", starts_on: Date.new(2026, 8, 11))
      completed_account = create(:transaction, :completed, user:, account:, description: "Completed bill", starts_on: Date.new(2026, 8, 20))

      expect(listed_ids(list(statuses: nil, on: nil))).to match_array(listed_ids(list))
      expect(listed_ids(list(statuses: nil, on: nil))).to contain_exactly(pending_account.id, completed_account.id)
    end
  end

  describe "#list_transfers" do
    it "returns the same rows with no filters as the current unfiltered listing" do
      pending_transfer = create(
        :transaction,
        :transfer,
        user:,
        source_account:,
        destination_account:,
        description: "Pending move",
        starts_on: Date.new(2026, 8, 11)
      )
      active_transfer = create(
        :transaction,
        :transfer,
        :active,
        user:,
        source_account:,
        destination_account:,
        description: "Active move",
        starts_on: Date.new(2026, 8, 12)
      )
      completed_transfer = create(
        :transaction,
        :transfer,
        :completed,
        user:,
        source_account:,
        destination_account:,
        description: "Completed move",
        starts_on: Date.new(2026, 8, 13)
      )
      canceled_transfer = create(
        :transaction,
        :transfer,
        :canceled,
        user:,
        source_account:,
        destination_account:,
        description: "Canceled move",
        starts_on: Date.new(2026, 8, 11),
        canceled_on: Date.new(2026, 8, 15)
      )

      result = list_transfers

      expect(result).to be_a(Solid::Success)
      expect(result.type).to eq(:monthly_statement_transfers_listed)
      expect(listed_ids(result, key: :monthly_statement_transfers)).to contain_exactly(
        pending_transfer.id,
        active_transfer.id,
        completed_transfer.id,
        canceled_transfer.id
      )
    end

    it "excludes completed and canceled transfers when statuses is pending and active" do
      pending_transfer = create(
        :transaction,
        :transfer,
        user:,
        source_account:,
        destination_account:,
        description: "Pending move",
        starts_on: Date.new(2026, 8, 11)
      )
      active_transfer = create(
        :transaction,
        :transfer,
        :active,
        user:,
        source_account:,
        destination_account:,
        description: "Active move",
        starts_on: Date.new(2026, 8, 12)
      )
      create(
        :transaction,
        :transfer,
        :completed,
        user:,
        source_account:,
        destination_account:,
        description: "Completed move",
        starts_on: Date.new(2026, 8, 13)
      )
      create(
        :transaction,
        :transfer,
        :canceled,
        user:,
        source_account:,
        destination_account:,
        description: "Canceled move",
        starts_on: Date.new(2026, 8, 11),
        canceled_on: Date.new(2026, 8, 15)
      )

      result = list_transfers(statuses: %w[pending active])

      expect(result).to be_a(Solid::Success)
      expect(listed_ids(result, key: :monthly_statement_transfers)).to contain_exactly(pending_transfer.id, active_transfer.id)
    end

    it "returns only occurrences with current_recurrence_on on or before on" do
      included_transfer = create(
        :transaction,
        :transfer,
        user:,
        source_account:,
        destination_account:,
        description: "Early move",
        starts_on: Date.new(2026, 8, 5)
      )
      create(
        :transaction,
        :transfer,
        user:,
        source_account:,
        destination_account:,
        description: "Late move",
        starts_on: Date.new(2026, 8, 20)
      )

      result = list_transfers(on: Date.new(2026, 8, 10))

      expect(result).to be_a(Solid::Success)
      expect(listed_ids(result, key: :monthly_statement_transfers)).to contain_exactly(included_transfer.id)
    end

    it "treats explicit statuses: nil and on: nil as omitting the filters" do
      pending_transfer = create(
        :transaction,
        :transfer,
        user:,
        source_account:,
        destination_account:,
        description: "Pending move",
        starts_on: Date.new(2026, 8, 11)
      )
      completed_transfer = create(
        :transaction,
        :transfer,
        :completed,
        user:,
        source_account:,
        destination_account:,
        description: "Completed move",
        starts_on: Date.new(2026, 8, 20)
      )

      expect(listed_ids(list_transfers(statuses: nil, on: nil), key: :monthly_statement_transfers))
        .to match_array(listed_ids(list_transfers, key: :monthly_statement_transfers))
      expect(listed_ids(list_transfers(statuses: nil, on: nil), key: :monthly_statement_transfers))
        .to contain_exactly(pending_transfer.id, completed_transfer.id)
    end
  end
end
