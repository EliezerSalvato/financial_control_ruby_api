require "rails_helper"

RSpec.describe "core process persist and not-found failures" do
  include ActiveSupport::Testing::TimeHelpers

  let(:user) { create(:user, :verified) }
  let(:user_entity) { User::Mapper.to_entity(user) }
  let(:errors) { Core::Errors.new(base: [ "invalid" ]) }

  def failure(type = :failed, **value)
    Solid::Failure(type, **value)
  end

  describe "listing invalid_filters" do
    [
      [ Core::Account::Listing, Account::Adapters.repository ],
      [ Core::Category::Listing, Category::Adapters.repository ],
      [ Core::Institution::Listing, Institution::Adapters.repository ],
      [ Core::Tag::Listing, Tag::Adapters.repository ],
      [ Core::CreditCard::Listing, CreditCard::Adapters.repository ],
      [ Core::Transaction::Listing, Transaction::Adapters.repository ]
    ].each do |process, repository|
      it "returns invalid_filters for #{process}" do
        allow(repository).to receive(:list).and_return(failure(:invalid_filters))

        result = process.call(user: user_entity)

        expect(result).to be_a(Solid::Failure)
        expect(result.type).to eq(:invalid_filters)
        expect(result.value[:input].errors.details[:q]).to be_present
      end
    end
  end

  describe "CRUD persist failures" do
    it "fails account creation when the repository cannot persist" do
      allow(Account::Adapters.repository).to receive(:exists?).and_return(false)
      allow(Account::Adapters.repository).to receive(:create).and_return(failure(:account_creation_failed, errors:))

      result = Core::Account::Creation.call(user: user_entity, name: "Wallet", kind: "cash", color: "#3B82F6")

      expect(result.type).to eq(:account_creation_failed)
    end

    it "fails account update when the repository cannot persist" do
      account = create(:account, user:)
      allow(Account::Adapters.repository).to receive(:update).and_return(failure(:account_update_failed, errors:))

      result = Core::Account::Update.call(user: user_entity, id: account.id, name: "Cash")

      expect(result.type).to eq(:account_update_failed)
    end

    it "fails account deletion when the repository cannot destroy" do
      account = create(:account, user:)
      allow(Account::Adapters.repository).to receive(:destroy).and_return(failure(:account_destruction_failed))

      result = Core::Account::Deletion.call(user: user_entity, id: account.id)

      expect(result.type).to eq(:account_destruction_failed)
    end

    it "returns not_found when updating a bank account to an unknown institution" do
      account = create(:account, :bank_account, user:)

      result = Core::Account::Update.call(user: user_entity, id: account.id, institution_id: UUID.generate)

      expect(result.type).to eq(:invalid_input)
      expect(result.value[:input].errors[:institution_id]).to be_present
    end

    it "fails category, institution and tag persistence" do
      allow(Category::Adapters.repository).to receive(:exists?).and_return(false)
      allow(Category::Adapters.repository).to receive(:create).and_return(failure(:category_creation_failed, errors:))
      expect(Core::Category::Creation.call(user: user_entity, name: "Food", color: "#3B82F6").type).to eq(:category_creation_failed)

      category = create(:category, user:)
      allow(Category::Adapters.repository).to receive(:update).and_return(failure(:category_update_failed, errors:))
      expect(Core::Category::Update.call(user: user_entity, id: category.id, name: "Groceries").type).to eq(:category_update_failed)
      allow(Category::Adapters.repository).to receive(:destroy).and_return(failure(:category_destruction_failed))
      expect(Core::Category::Deletion.call(user: user_entity, id: category.id).type).to eq(:category_destruction_failed)

      allow(Institution::Adapters.repository).to receive(:exists?).and_return(false)
      allow(Institution::Adapters.repository).to receive(:create).and_return(failure(:institution_creation_failed, errors:))
      expect(Core::Institution::Creation.call(user: user_entity, name: "Nubank", logo_key: "nubank").type).to eq(:institution_creation_failed)

      institution = create(:institution, user:)
      allow(Institution::Adapters.repository).to receive(:update).and_return(failure(:institution_update_failed, errors:))
      expect(Core::Institution::Update.call(user: user_entity, id: institution.id, name: "Bank").type).to eq(:institution_update_failed)
      allow(Institution::Adapters.repository).to receive(:destroy).and_return(failure(:institution_destruction_failed))
      expect(Core::Institution::Deletion.call(user: user_entity, id: institution.id).type).to eq(:institution_destruction_failed)

      allow(Tag::Adapters.repository).to receive(:exists?).and_return(false)
      allow(Tag::Adapters.repository).to receive(:create).and_return(failure(:tag_creation_failed, errors:))
      expect(Core::Tag::Creation.call(user: user_entity, name: "Trip", color: "#3B82F6").type).to eq(:tag_creation_failed)

      tag = create(:tag, user:)
      allow(Tag::Adapters.repository).to receive(:update).and_return(failure(:tag_update_failed, errors:))
      expect(Core::Tag::Update.call(user: user_entity, id: tag.id, name: "Travel").type).to eq(:tag_update_failed)
      allow(Tag::Adapters.repository).to receive(:destroy).and_return(failure(:tag_destruction_failed))
      expect(Core::Tag::Deletion.call(user: user_entity, id: tag.id).type).to eq(:tag_destruction_failed)
    end

    it "fails credit card creation and update persistence and unknown associations" do
      institution = create(:institution, user:)
      account = create(:account, :bank_account, user:, institution:)
      allow(CreditCard::Adapters.repository).to receive(:exists?).and_return(false)
      allow(CreditCard::Adapters.repository).to receive(:create).and_return(failure(:credit_card_creation_failed, errors:))

      result = Core::CreditCard::Creation.call(
        user: user_entity,
        institution_id: institution.id,
        default_payment_account_id: account.id,
        name: "Platinum",
        closing_day: 10,
        due_day: 17,
        network: "mastercard"
      )
      expect(result.type).to eq(:credit_card_creation_failed)

      credit_card = create(:credit_card, user:, institution:, default_payment_account: account)
      allow(CreditCard::Adapters.repository).to receive(:update).and_return(failure(:credit_card_update_failed, errors:))
      expect(Core::CreditCard::Update.call(user: user_entity, id: credit_card.id, name: "Gold").type).to eq(:credit_card_update_failed)

      allow(CreditCard::Adapters.repository).to receive(:destroy).and_return(failure(:credit_card_destruction_failed))
      expect(Core::CreditCard::Deletion.call(user: user_entity, id: credit_card.id).type).to eq(:credit_card_destruction_failed)

      expect(Core::CreditCard::Update.call(user: user_entity, id: credit_card.id, institution_id: UUID.generate).type).to eq(:invalid_input)
      expect(Core::CreditCard::Update.call(user: user_entity, id: credit_card.id, default_payment_account_id: UUID.generate).type).to eq(:invalid_input)
    end
  end

  describe "transactions" do
    let(:account) { create(:account, user:) }
    let(:category) { create(:category, user:) }

    def create_params(**overrides)
      {
        user: user_entity,
        description: "Rent",
        kind: "expense",
        payment_method: "pix",
        recurrence_type: "one_time",
        starts_on: Date.new(2026, 8, 11),
        value: 100,
        account_id: account.id,
        category_id: category.id,
        **overrides
      }
    end

    it "rejects unknown category and tags on create" do
      expect(Core::Transaction::Creation.call(**create_params(category_id: UUID.generate)).type).to eq(:invalid_input)
      expect(Core::Transaction::Creation.call(**create_params(tag_ids: [ UUID.generate ])).type).to eq(:invalid_input)
    end

    it "fails when the transaction repository cannot persist on create" do
      allow(Transaction::Adapters.repository).to receive(:create).and_return(failure(:transaction_creation_failed, errors:))

      expect(Core::Transaction::Creation.call(**create_params).type).to eq(:transaction_creation_failed)
    end

    it "fails when nested for_account creation cannot persist" do
      allow(Transaction::Adapters.transaction_for_account_repository).to receive(:create).and_return(failure(:for_account_creation_failed, errors:))

      expect(Core::Transaction::Creation.call(**create_params).type).to eq(:transaction_creation_failed)
    end

    it "fails when nested credit card creation cannot persist" do
      credit_card = create(:credit_card, user:)
      allow(Transaction::Adapters.transaction_for_credit_card_repository).to receive(:create).and_return(failure(:for_credit_card_creation_failed, errors:))

      expect(
        Core::Transaction::Creation.call(**create_params(payment_method: "credit_card", credit_card_id: credit_card.id, account_id: nil)).type
      ).to eq(:transaction_creation_failed)
    end

    it "fails when nested transfer creation cannot persist" do
      destination = create(:account, user:)
      allow(Transaction::Adapters.transaction_for_transfer_between_accounts_repository).to receive(:create)
        .and_return(failure(:for_transfer_between_accounts_creation_failed, errors:))

      expect(
        Core::Transaction::Creation.call(
          **create_params(kind: "transfer_between_accounts", payment_method: nil, source_account_id: account.id, destination_account_id: destination.id)
        ).type
      ).to eq(:transaction_creation_failed)
    end

    it "fails when recurrence creation cannot persist" do
      allow(Transaction::Adapters.recurrence_repository).to receive(:create).and_return(failure(:recurrence_creation_failed, errors:))

      expect(Core::Transaction::Creation.call(**create_params).type).to eq(:transaction_creation_failed)
    end

    it "fails when taggings cannot be replaced on create" do
      tag = create(:tag, user:)
      allow(Transaction::Adapters.tagging_repository).to receive(:sync).and_return(failure(:taggings_replace_failed, errors:))

      expect(Core::Transaction::Creation.call(**create_params(tag_ids: [ tag.id ])).type).to eq(:transaction_creation_failed)
    end

    it "fails when the created transaction cannot be reloaded" do
      allow(Transaction::Adapters.repository).to receive(:find_by_id).and_return(failure(:transaction_not_found))

      expect(Core::Transaction::Creation.call(**create_params).type).to eq(:transaction_creation_failed)
    end

    it "rejects unknown category and tags on update" do
      transaction = create(:transaction, user:, account:, category:)

      expect(Core::Transaction::Update.call(user: user_entity, id: transaction.id, category_id: UUID.generate).type).to eq(:invalid_input)
      expect(Core::Transaction::Update.call(user: user_entity, id: transaction.id, tag_ids: [ UUID.generate ]).type).to eq(:invalid_input)
    end

    it "fails when the transaction repository cannot persist on update" do
      transaction = create(:transaction, user:, account:, category:)
      allow(Transaction::Adapters.repository).to receive(:update).and_return(failure(:transaction_update_failed, errors:))

      expect(Core::Transaction::Update.call(user: user_entity, id: transaction.id, description: "Updated").type).to eq(:transaction_update_failed)
    end

    it "fails when taggings cannot be replaced on update" do
      tag = create(:tag, user:)
      transaction = create(:transaction, user:, account:, category:)
      allow(Transaction::Adapters.tagging_repository).to receive(:sync).and_return(failure(:taggings_replace_failed, errors:))

      expect(Core::Transaction::Update.call(user: user_entity, id: transaction.id, tag_ids: [ tag.id ]).type).to eq(:transaction_update_failed)
    end

    it "fails when the updated transaction cannot be reloaded" do
      transaction = create(:transaction, user:, account:, category:)
      find_calls = 0
      allow(Transaction::Adapters.repository).to receive(:find_by_id).and_wrap_original do |original, **kwargs|
        find_calls += 1
        find_calls > 1 ? failure(:transaction_not_found) : original.call(**kwargs)
      end

      expect(Core::Transaction::Update.call(user: user_entity, id: transaction.id, description: "Updated").type).to eq(:transaction_update_failed)
    end

    it "fails cancellation and deletion when the repository cannot persist" do
      transaction = create(:transaction, :active, user:, account:, category:)
      allow(Transaction::Adapters.repository).to receive(:update).and_return(failure(:transaction_update_failed, errors:))
      expect(Core::Transaction::Cancellation.call(user: user_entity, id: transaction.id).type).to eq(:transaction_cancellation_failed)

      pending = create(:transaction, user:, account:, category:)
      allow(Transaction::Adapters.repository).to receive(:destroy).and_return(failure(:transaction_destruction_failed))
      expect(Core::Transaction::Deletion.call(user: user_entity, id: pending.id).type).to eq(:transaction_destruction_failed)
    end
  end

  describe "nested transaction dependents" do
    let(:transaction) { Transaction::Mapper.to_entity(create(:transaction, user:)) }

    it "rejects unknown accounts and persist failures for for_account" do
      expect(
        Core::Transaction::ForAccount::Creation.call(user: user_entity, transaction:, account_id: UUID.generate).type
      ).to eq(:invalid_input)

      allow(Transaction::Adapters.transaction_for_account_repository).to receive(:create).and_return(failure(:for_account_creation_failed, errors:))
      account = create(:account, user:)
      expect(
        Core::Transaction::ForAccount::Creation.call(user: user_entity, transaction:, account_id: account.id).type
      ).to eq(:for_account_creation_failed)

      expect(
        Core::Transaction::ForAccount::Update.call(user: user_entity, transaction:, account_id: UUID.generate).type
      ).to eq(:invalid_input)

      allow(Transaction::Adapters.transaction_for_account_repository).to receive(:upsert).and_return(failure(:for_account_upsert_failed, errors:))
      expect(
        Core::Transaction::ForAccount::Update.call(user: user_entity, transaction:, account_id: create(:account, user:).id).type
      ).to eq(:for_account_upsert_failed)

      allow(Transaction::Adapters.transaction_for_account_repository).to receive(:destroy).and_return(failure(:for_account_destruction_failed, errors:))
      expect(
        Core::Transaction::ForAccount::Update.call(
          user: user_entity,
          transaction:,
          kind: Core::Transaction::Kind::TRANSFER_BETWEEN_ACCOUNTS
        ).type
      ).to eq(:for_account_destruction_failed)
    end

    it "rejects unknown cards and persist failures for for_credit_card" do
      expect(
        Core::Transaction::ForCreditCard::Creation.call(
          user: user_entity,
          transaction:,
          payment_method: "credit_card",
          recurrence_type: "one_time",
          credit_card_id: UUID.generate
        ).type
      ).to eq(:invalid_input)

      credit_card = create(:credit_card, user:)
      allow(Transaction::Adapters.transaction_for_credit_card_repository).to receive(:create).and_return(failure(:for_credit_card_creation_failed, errors:))
      expect(
        Core::Transaction::ForCreditCard::Creation.call(
          user: user_entity,
          transaction:,
          payment_method: "credit_card",
          recurrence_type: "one_time",
          credit_card_id: credit_card.id
        ).type
      ).to eq(:for_credit_card_creation_failed)

      card_transaction = Transaction::Mapper.to_entity(create(:transaction, :with_credit_card, user:))
      expect(
        Core::Transaction::ForCreditCard::Update.call(
          user: user_entity,
          transaction: card_transaction,
          payment_method: "credit_card",
          credit_card_id: UUID.generate
        ).type
      ).to eq(:invalid_input)

      allow(Transaction::Adapters.transaction_for_credit_card_repository).to receive(:upsert).and_return(failure(:for_credit_card_upsert_failed, errors:))
      expect(
        Core::Transaction::ForCreditCard::Update.call(
          user: user_entity,
          transaction: card_transaction,
          payment_method: "credit_card",
          credit_card_id: credit_card.id
        ).type
      ).to eq(:for_credit_card_upsert_failed)

      allow(Transaction::Adapters.transaction_for_credit_card_repository).to receive(:destroy).and_return(failure(:for_credit_card_destruction_failed, errors:))
      expect(
        Core::Transaction::ForCreditCard::Update.call(
          user: user_entity,
          transaction: card_transaction,
          payment_method: "pix"
        ).type
      ).to eq(:for_credit_card_destruction_failed)
    end

    it "rejects unknown accounts and persist failures for transfers" do
      source = create(:account, user:)
      destination = create(:account, user:)
      transfer = Transaction::Mapper.to_entity(create(:transaction, :transfer, user:, source_account: source, destination_account: destination))

      expect(
        Core::Transaction::ForTransferBetweenAccounts::Creation.call(
          user: user_entity,
          transaction:,
          source_account_id: UUID.generate,
          destination_account_id: destination.id
        ).type
      ).to eq(:invalid_input)

      allow(Transaction::Adapters.transaction_for_transfer_between_accounts_repository).to receive(:create)
        .and_return(failure(:for_transfer_between_accounts_creation_failed, errors:))
      expect(
        Core::Transaction::ForTransferBetweenAccounts::Creation.call(
          user: user_entity,
          transaction:,
          source_account_id: source.id,
          destination_account_id: destination.id
        ).type
      ).to eq(:for_transfer_between_accounts_creation_failed)

      expect(
        Core::Transaction::ForTransferBetweenAccounts::Update.call(
          user: user_entity,
          transaction: transfer,
          kind: Core::Transaction::Kind::TRANSFER_BETWEEN_ACCOUNTS,
          source_account_id: UUID.generate
        ).type
      ).to eq(:invalid_input)

      allow(Transaction::Adapters.transaction_for_transfer_between_accounts_repository).to receive(:upsert)
        .and_return(failure(:for_transfer_between_accounts_upsert_failed, errors:))
      expect(
        Core::Transaction::ForTransferBetweenAccounts::Update.call(
          user: user_entity,
          transaction: transfer,
          kind: Core::Transaction::Kind::TRANSFER_BETWEEN_ACCOUNTS,
          source_account_id: source.id,
          destination_account_id: destination.id
        ).type
      ).to eq(:for_transfer_between_accounts_upsert_failed)

      allow(Transaction::Adapters.transaction_for_transfer_between_accounts_repository).to receive(:destroy)
        .and_return(failure(:for_transfer_between_accounts_destruction_failed, errors:))
      expect(
        Core::Transaction::ForTransferBetweenAccounts::Update.call(
          user: user_entity,
          transaction: transfer,
          kind: Core::Transaction::Kind::EXPENSE
        ).type
      ).to eq(:for_transfer_between_accounts_destruction_failed)
    end
  end

  describe "recurrence" do
    it "fails recurrence creation persist" do
      transaction = Transaction::Mapper.to_entity(create(:transaction, user:))
      allow(Transaction::Adapters.recurrence_repository).to receive(:create).and_return(failure(:recurrence_creation_failed, errors:))

      expect(
        Core::Transaction::Recurrence::Creation.call(
          transaction:,
          recurrence_type: "one_time",
          starts_on: Date.new(2026, 8, 11),
          value: 10
        ).type
      ).to eq(:recurrence_creation_failed)
    end

    it "rejects an inverted recurrence window and persist failures on update" do
      pending_transaction = Transaction::Mapper.to_entity(create(:transaction, user:))
      active_transaction = Transaction::Mapper.to_entity(create(:transaction, :active, user:))

      result = Core::Transaction::Recurrence::Update.call(transaction: active_transaction, ends_on: Date.new(2026, 7, 1))
      expect(result.type).to eq(:invalid_input)

      allow(Transaction::Adapters.recurrence_repository).to receive(:update).and_return(failure(:recurrence_update_failed, errors:))
      expect(
        Core::Transaction::Recurrence::Update.call(transaction: pending_transaction, starts_on: Date.new(2026, 8, 11), value: 20).type
      ).to eq(:recurrence_update_failed)

      allow(Transaction::Adapters.recurrence_repository).to receive(:update).and_call_original
      allow(Transaction::Adapters.recurrence_repository).to receive(:find_latest).and_return(failure(:recurrence_not_found))
      expect(Core::Transaction::Recurrence::Update.call(transaction: pending_transaction, value: 20)).to be_a(Solid::Success)
    end

    it "creates a missing recurrence and fails when that persist fails" do
      transaction = Transaction::Mapper.to_entity(create(:transaction, user:))
      allow(Transaction::Adapters.recurrence_repository).to receive(:find_latest).and_return(failure(:recurrence_not_found))
      allow(Transaction::Adapters.recurrence_repository).to receive(:create).and_return(failure(:recurrence_creation_failed, errors:))

      expect(
        Core::Transaction::Recurrence::Update.call(transaction:, starts_on: Date.new(2026, 8, 11), value: 20).type
      ).to eq(:recurrence_creation_failed)
    end

    it "creates a missing recurrence when the latest one cannot be found" do
      transaction = Transaction::Mapper.to_entity(create(:transaction, user:))
      allow(Transaction::Adapters.recurrence_repository).to receive(:find_latest).and_return(failure(:recurrence_not_found))
      allow(Transaction::Adapters.recurrence_repository).to receive(:create).and_return(Solid::Success(:recurrence_created))

      result = Core::Transaction::Recurrence::Update.call(
        transaction:,
        starts_on: Date.new(2026, 8, 11),
        value: 20
      )

      expect(result).to be_a(Solid::Success)
    end

    it "fails recurrence change persist paths" do
      transaction = create(:transaction, :recurring, :active, user:)
      entity = Transaction::Mapper.to_entity(transaction)

      allow(Transaction::Adapters.recurrence_repository).to receive(:create).and_return(failure(:recurrence_creation_failed, errors:))
      expect(
        Core::Transaction::Recurrence::Change.call(
          user: user_entity,
          transaction_id: transaction.id,
          starts_on: Date.new(2026, 9, 11),
          value: 50
        ).type
      ).to eq(:recurrence_change_failed)

      allow(Transaction::Adapters.recurrence_repository).to receive(:create).and_call_original
      allow(Transaction::Adapters.recurrence_repository).to receive(:update).and_return(failure(:recurrence_update_failed, errors:))
      expect(
        Core::Transaction::Recurrence::Change.call(
          user: user_entity,
          transaction_id: transaction.id,
          starts_on: entity.recurrences.first.starts_on,
          value: 50
        ).type
      ).to eq(:recurrence_change_failed)

      allow(Transaction::Adapters.recurrence_repository).to receive(:update).and_call_original
      allow(Transaction::Adapters.recurrence_repository).to receive(:destroy_after).and_return(failure(:recurrence_destruction_failed, errors:))
      expect(
        Core::Transaction::Recurrence::Change.call(
          user: user_entity,
          transaction_id: transaction.id,
          starts_on: Date.new(2026, 9, 11),
          value: 50,
          change_for_next_months: true
        ).type
      ).to eq(:recurrence_change_failed)

      allow(Transaction::Adapters.recurrence_repository).to receive(:destroy_after).and_call_original
      find_calls = 0
      allow(Transaction::Adapters.repository).to receive(:find_by_id).and_wrap_original do |original, **kwargs|
        find_calls += 1
        find_calls > 1 ? failure(:transaction_not_found) : original.call(**kwargs)
      end
      expect(
        Core::Transaction::Recurrence::Change.call(
          user: user_entity,
          transaction_id: transaction.id,
          starts_on: Date.new(2026, 9, 11),
          value: 50
        ).type
      ).to eq(:recurrence_change_failed)
    end
  end

  describe "settlement creation" do
    it "returns transaction_not_found" do
      expect(
        Core::Transaction::Settlement::Creation.call(
          user: user_entity,
          transaction_id: UUID.generate,
          occurred_on: Date.new(2026, 8, 11),
          value: 10
        ).type
      ).to eq(:transaction_not_found)
    end

    it "fails when the settlement cannot be persisted" do
      transaction = create(:transaction, user:)
      allow(Transaction::Adapters.settlement_repository).to receive(:create).and_return(failure(:transaction_settlement_creation_failed, errors:))

      expect(
        Core::Transaction::Settlement::Creation.call(
          user: user_entity,
          transaction_id: transaction.id,
          occurred_on: Date.new(2026, 8, 11),
          value: 10
        ).type
      ).to eq(:transaction_settlement_creation_failed)
    end

    it "fails when advancing status cannot persist" do
      account = create(:account, :allow_negative_balance, user:, current_balance: 100)
      transaction = create(:transaction, user:, account:)
      allow(Transaction::Adapters.repository).to receive(:update).and_return(failure(:transaction_update_failed, errors:))

      expect(
        Core::Transaction::Settlement::Creation.call(
          user: user_entity,
          transaction_id: transaction.id,
          occurred_on: Date.new(2026, 8, 11),
          value: 10
        ).type
      ).to eq(:transaction_settlement_creation_failed)
    end

    it "fails when the payment account cannot be found" do
      transaction = create(:transaction, user:)
      allow(Account::Adapters.repository).to receive(:find_by_id).and_return(failure(:account_not_found))

      expect(
        Core::Transaction::Settlement::Creation.call(
          user: user_entity,
          transaction_id: transaction.id,
          occurred_on: Date.new(2026, 8, 11),
          value: 10
        ).type
      ).to eq(:transaction_settlement_creation_failed)
    end

    it "propagates a transfer debit failure" do
      source = create(:account, :bank_account, user:, current_balance: 5)
      destination = create(:account, :bank_account, user:, current_balance: 0)
      transaction = create(:transaction, :transfer, user:, source_account: source, destination_account: destination, value: 10)

      result = Core::Transaction::Settlement::Creation.call(
        user: user_entity,
        transaction_id: transaction.id,
        occurred_on: Date.new(2026, 8, 11),
        value: 10
      )

      expect(result).to be_a(Solid::Failure)
    end

    it "fails when the credit card cannot be found while applying limit" do
      transaction = create(:transaction, :with_credit_card, user:, value: 10)
      allow(CreditCard::Adapters.repository).to receive(:find_by_id).and_return(failure(:credit_card_not_found))

      expect(
        Core::Transaction::Settlement::Creation.call(
          user: user_entity,
          transaction_id: transaction.id,
          occurred_on: Date.new(2026, 8, 11),
          value: 10
        ).type
      ).to eq(:transaction_settlement_creation_failed)
    end

    it "continues when the settlement has no financial effect type" do
      process = Core::Transaction::Settlement::Creation.new
      settlement = double(for_account?: false, for_transfer_between_accounts?: false, for_credit_card?: false)

      result = process.send(
        :apply_financial_effects,
        already_settled: false,
        user: user_entity,
        settlement:,
        transaction: nil,
        value: 1
      )

      expect(result).to be_a(Solid::Success)
    end

    it "returns false when installment completion cannot count settlements" do
      process = Core::Transaction::Settlement::Creation.new
      transaction = double(ends_on: Date.new(2026, 8, 11), installments_count: 2, id: UUID.generate)
      allow(process).to receive_message_chain(:deps, :settlement_repository, :count_for).and_return(failure(:oops))

      expect(process.send(:installment_completed?, transaction, Date.new(2026, 8, 11))).to be(false)
    end
  end

  describe "invoice settlement creation" do
    it "returns credit_card_not_found" do
      expect(
        Core::CreditCard::InvoiceSettlement::Creation.call(
          user: user_entity,
          credit_card_id: UUID.generate,
          payment_account_id: UUID.generate,
          opening_date: Date.new(2026, 8, 1),
          closing_date: Date.new(2026, 8, 10),
          due_date: Date.new(2026, 8, 17),
          total_value: 10
        ).type
      ).to eq(:credit_card_not_found)
    end

    it "fails when the invoice cannot be persisted" do
      credit_card = create(:credit_card, user:)
      allow(CreditCard::Adapters.invoice_settlement_repository).to receive(:create)
        .and_return(failure(:credit_card_invoice_settlement_creation_failed, errors:))

      expect(
        Core::CreditCard::InvoiceSettlement::Creation.call(
          user: user_entity,
          credit_card_id: credit_card.id,
          payment_account_id: credit_card.default_payment_account_id,
          opening_date: Date.new(2026, 8, 1),
          closing_date: Date.new(2026, 8, 10),
          due_date: Date.new(2026, 8, 17),
          total_value: 10
        ).type
      ).to eq(:credit_card_invoice_settlement_creation_failed)
    end

    it "fails when the payment account cannot be found" do
      credit_card = create(:credit_card, user:)
      allow(Account::Adapters.repository).to receive(:find_by_id).and_return(failure(:account_not_found))

      expect(
        Core::CreditCard::InvoiceSettlement::Creation.call(
          user: user_entity,
          credit_card_id: credit_card.id,
          payment_account_id: credit_card.default_payment_account_id,
          opening_date: Date.new(2026, 8, 1),
          closing_date: Date.new(2026, 8, 10),
          due_date: Date.new(2026, 8, 17),
          total_value: 10
        ).type
      ).to eq(:credit_card_invoice_settlement_creation_failed)
    end
  end

  describe "notifications and monthly status" do
    it "fails notification creation persist" do
      allow(Notification::Adapters.repository).to receive(:create).and_return(failure(:notification_creation_failed, errors:))

      expect(Core::Notification::Creation.call(user_id: user.id, kind: "system", title: "Hi").type).to eq(:notification_creation_failed)
    end

    it "fails mark as read persist" do
      notification = create(:notification, user:)
      allow(Notification::Adapters.repository).to receive(:mark_as_read).and_return(failure(:notification_mark_as_read_failed, errors:))

      expect(Core::Notification::MarkAsRead.call(user_id: user.id, id: notification.id).type).to eq(:notification_mark_as_read_failed)
    end

    it "fails mark all as read when the repository does not succeed" do
      allow(Notification::Adapters.repository).to receive(:mark_all_as_read).and_return(failure(:unexpected))

      expect(Core::Notification::MarkAllAsRead.call(user_id: user.id).type).to eq(:notifications_mark_as_read_failed)
    end

    it "fails monthly status create and update persist" do
      allow(MonthlyStatus::Adapters.repository).to receive(:find).and_return(failure(:monthly_status_not_found))
      allow(MonthlyStatus::Adapters.repository).to receive(:exists_closed_after?).and_return(false)
      allow(MonthlyStatus::Adapters.repository).to receive(:create).and_return(failure(:monthly_status_creation_failed, errors:))

      expect(Core::MonthlyStatus::Update.call(user: user_entity, month: 8, year: 2026, status: "open").type).to eq(:monthly_status_creation_failed)

      monthly_status = create(:monthly_status, user:, month: 8, year: 2026)
      allow(MonthlyStatus::Adapters.repository).to receive(:find).and_call_original
      allow(MonthlyStatus::Adapters.repository).to receive(:update).and_return(failure(:monthly_status_update_failed, errors:))
      expect(Core::MonthlyStatus::Update.call(user: user_entity, month: 8, year: 2026, status: "open").type).to eq(:monthly_status_update_failed)

      allow(MonthlyStatus::Adapters.repository).to receive(:close).and_return(failure(:monthly_status_closing_failed, errors:))
      travel_to(Date.new(2026, 9, 10)) do
        expect(Core::MonthlyStatus::Closing.call(user_id: user.id, month: 8, year: 2026).type).to eq(:monthly_status_closing_failed)
      end
    end

    it "fails ensure_open create persist" do
      allow(MonthlyStatus::Adapters.repository).to receive(:find).and_return(failure(:monthly_status_not_found))
      allow(MonthlyStatus::Adapters.repository).to receive(:exists_closed_after?).and_return(false)
      allow(MonthlyStatus::Adapters.repository).to receive(:create).and_return(failure(:monthly_status_creation_failed, errors:))

      expect(
        Core::MonthlyStatus::EnsureOpen.call(user: user_entity, date: Date.new(2026, 8, 11), payment_method: "pix")
      ).to be_a(Solid::Failure)
    end
  end

  describe "user flows" do
    it "fails registration persist steps" do
      allow(User::Adapters.repository).to receive(:exists?).and_return(false)
      allow(User::Adapters.repository).to receive(:create).and_return(failure(:user_creation_failed, errors:))
      expect(
        Core::User::Registration.call(
          first_name: "Jane",
          last_name: "Doe",
          email: "jane-reg@example.com",
          password: "password123",
          password_confirmation: "password123"
        ).type
      ).to eq(:user_creation_failed)

      allow(User::Adapters.repository).to receive(:create).and_call_original
      allow(User::Adapters.email_confirmation_repository).to receive(:create).and_return(failure(:email_confirmation_creation_failed, errors:))
      expect(
        Core::User::Registration.call(
          first_name: "Jane",
          last_name: "Doe",
          email: "jane-reg-2@example.com",
          password: "password123",
          password_confirmation: "password123"
        ).type
      ).to eq(:email_confirmation_creation_failed)
    end

    it "fails authentication persist steps" do
      allow(User::Adapters.repository).to receive(:update_profile).and_return(failure(:profile_update_failed, errors:))
      expect(
        Core::User::Authentication.call(
          email: user.email,
          password: "password123",
          locale: "pt-BR",
          ip_address: "127.0.0.1",
          user_agent: "rspec"
        ).type
      ).to eq(:locale_sync_failed)

      allow(User::Adapters.repository).to receive(:update_profile).and_call_original
      allow(User::Adapters.session_repository).to receive(:revoke_all_by).and_return(failure(:sessions_revocation_failed))
      expect(
        Core::User::Authentication.call(
          email: user.email,
          password: "password123",
          ip_address: "127.0.0.1",
          user_agent: "rspec"
        ).type
      ).to eq(:sessions_revocation_failed)

      allow(User::Adapters.session_repository).to receive(:revoke_all_by).and_call_original
      allow(User::Adapters.token).to receive(:generate).and_return("")
      expect(
        Core::User::Authentication.call(
          email: user.email,
          password: "password123",
          ip_address: "127.0.0.1",
          user_agent: "rspec"
        ).type
      ).to eq(:refresh_token_creation_failed)

      allow(User::Adapters.token).to receive(:generate).and_call_original
      allow(User::Adapters.session_repository).to receive(:create).and_return(failure(:session_creation_failed, errors:))
      expect(
        Core::User::Authentication.call(
          email: user.email,
          password: "password123",
          ip_address: "127.0.0.1",
          user_agent: "rspec"
        ).type
      ).to eq(:session_creation_failed)

      allow(User::Adapters.session_repository).to receive(:create).and_call_original
      allow(User::Adapters.token).to receive(:sign).and_return("")
      expect(
        Core::User::Authentication.call(
          email: user.email,
          password: "password123",
          ip_address: "127.0.0.1",
          user_agent: "rspec"
        ).type
      ).to eq(:signed_token_creation_failed)
    end

    it "fails profile, account deletion and session revoke persist" do
      allow(User::Adapters.repository).to receive(:update_profile).and_return(failure(:profile_update_failed, errors:))
      expect(Core::User::Profile::Update.call(user: user_entity, first_name: "Jane").type).to eq(:profile_update_failed)

      allow(User::Adapters.repository).to receive(:destroy).and_return(failure(:user_destruction_failed))
      expect(Core::User::Account::Deletion.call(user: user_entity, password: "password123").type).to eq(:account_deletion_failed)

      allow(User::Adapters.session_repository).to receive(:revoke_all_by).and_return(failure(:sessions_revocation_failed))
      expect(Core::User::Session::Revoke.call(user: user_entity).type).to eq(:sessions_revocation_failed)
    end

    it "fails password change persist" do
      allow(User::Adapters.repository).to receive(:update_password).and_return(failure(:password_update_failed, errors:))
      expect(
        Core::User::Password::Change.call(
          user: user_entity,
          current_password: "password123",
          password: "password456",
          password_confirmation: "password456"
        ).type
      ).to eq(:password_update_failed)

      allow(User::Adapters.repository).to receive(:update_password).and_call_original
      allow(User::Adapters.session_repository).to receive(:revoke_all_by).and_return(failure(:sessions_revocation_failed))
      expect(
        Core::User::Password::Change.call(
          user: user_entity,
          current_password: "password123",
          password: "password456",
          password_confirmation: "password456"
        ).type
      ).to eq(:sessions_revocation_failed)
    end

    it "fails email change persist" do
      allow(User::Adapters.repository).to receive(:change_email_and_mark_as_not_verified).and_return(failure(:change_email_and_mark_as_not_verified_failed))
      expect(
        Core::User::Email::Change.call(user: user_entity, current_password: "password123", new_email: "new-email@example.com").type
      ).to eq(:change_email_and_mark_as_not_verified_failed)

      allow(User::Adapters.repository).to receive(:change_email_and_mark_as_not_verified).and_call_original
      allow(User::Adapters.email_confirmation_repository).to receive(:invalidate_all_by).and_return(failure(:email_confirmations_invalidation_failed))
      expect(
        Core::User::Email::Change.call(user: user_entity, current_password: "password123", new_email: "new-email-2@example.com").type
      ).to eq(:email_confirmations_invalidation_failed)

      allow(User::Adapters.email_confirmation_repository).to receive(:invalidate_all_by).and_call_original
      allow(User::Adapters.email_confirmation_repository).to receive(:create).and_return(failure(:email_confirmation_creation_failed, errors:))
      expect(
        Core::User::Email::Change.call(user: user_entity, current_password: "password123", new_email: "new-email-3@example.com").type
      ).to eq(:email_confirmation_creation_failed)

      allow(User::Adapters.email_confirmation_repository).to receive(:create).and_call_original
      allow(User::Adapters.session_repository).to receive(:revoke_all_by).and_return(failure(:sessions_revocation_failed))
      expect(
        Core::User::Email::Change.call(user: user_entity, current_password: "password123", new_email: "new-email-4@example.com").type
      ).to eq(:sessions_revocation_failed)
    end

    it "fails email confirmation persist" do
      token = User::Adapters.token.generate_for(user: user_entity, purpose: :email_confirmation)
      create(:user_email_confirmation, user:, token:)

      allow(User::Adapters.repository).to receive(:mark_as_verified).and_return(failure(:mark_user_as_verified_failed))
      expect(Core::User::Email::Confirmation.call(token:).type).to eq(:mark_user_as_verified_failed)

      allow(User::Adapters.repository).to receive(:mark_as_verified).and_call_original
      allow(User::Adapters.email_confirmation_repository).to receive(:mark_as_confirmed).and_return(failure(:mark_email_confirmation_as_confirmed_failed))
      expect(Core::User::Email::Confirmation.call(token:).type).to eq(:mark_email_confirmation_as_confirmed_failed)
    end

    it "fails password reset instructions persist" do
      allow(User::Adapters.password_reset_repository).to receive(:invalidate_all_by).and_return(failure(:password_resets_invalidation_failed))
      expect(Core::User::Password::Reset::SendInstructions.call(email: user.email).type).to eq(:password_resets_invalidation_failed)

      allow(User::Adapters.password_reset_repository).to receive(:invalidate_all_by).and_call_original
      allow(User::Adapters.password_reset_repository).to receive(:create).and_return(failure(:password_reset_creation_failed, errors:))
      expect(Core::User::Password::Reset::SendInstructions.call(email: user.email).type).to eq(:password_reset_creation_failed)
    end

    it "fails password reset persist" do
      token = User::Adapters.token.generate_for(user: user_entity, purpose: :reset_password)
      create(:user_password_reset, user:, token:)

      allow(User::Adapters.repository).to receive(:update_password).and_return(failure(:password_update_failed, errors:))
      expect(
        Core::User::Password::Reset.call(token:, password: "password456", password_confirmation: "password456").type
      ).to eq(:password_update_failed)

      allow(User::Adapters.repository).to receive(:update_password).and_call_original
      allow(User::Adapters.password_reset_repository).to receive(:mark_as_reset).and_return(failure(:mark_password_reset_as_reset_failed))
      expect(
        Core::User::Password::Reset.call(token:, password: "password456", password_confirmation: "password456").type
      ).to eq(:mark_password_reset_as_reset_failed)

      allow(User::Adapters.password_reset_repository).to receive(:mark_as_reset).and_call_original
      allow(User::Adapters.session_repository).to receive(:revoke_all_by).and_return(failure(:sessions_revocation_failed))
      expect(
        Core::User::Password::Reset.call(token:, password: "password456", password_confirmation: "password456").type
      ).to eq(:sessions_revocation_failed)
    end

    it "fails session refresh persist" do
      refresh_token = User::Adapters.token.generate
      create(:user_session, user:, refresh_token:)

      allow(User::Adapters.token).to receive(:generate).and_return("")
      expect(Core::User::Session::Refresh.call(refresh_token:).type).to eq(:refresh_token_creation_failed)

      allow(User::Adapters.token).to receive(:generate).and_call_original
      allow(User::Adapters.session_repository).to receive(:update_refresh_token).and_return(failure(:refresh_token_update_failed, errors:))
      expect(Core::User::Session::Refresh.call(refresh_token:).type).to eq(:refresh_token_update_failed)

      allow(User::Adapters.session_repository).to receive(:update_refresh_token).and_call_original
      allow(User::Adapters.token).to receive(:sign).and_return("")
      expect(Core::User::Session::Refresh.call(refresh_token:).type).to eq(:signed_token_creation_failed)
    end
  end

  describe "notifying nested failures" do
    it "continues when notification creation succeeds without a notification payload" do
      allow(Notification).to receive(:create).and_return(Solid::Success(:ok))
      allow(Notification).to receive(:create_all).and_return(Solid::Success(:ok))

      expect(
        Core::MonthlyStatus::Closing::UnexpectedErrorNotifying.call(user_id: user.id, type: :unexpected, error: "boom").type
      ).not_to eq(:notification_creation_failed)
      expect(
        Core::Settlement::Processing::UnexpectedErrorNotifying.call(user_id: user.id, month: 8, year: 2026, type: :unexpected, error: "boom")
      ).to be_a(Solid::Success)
      expect(
        Core::Settlement::Processing::ValidationErrorNotifying.call(user_id: user.id, month: 8, year: 2026, type: :invalid_input)
      ).to be_a(Solid::Success)
      expect(
        Core::MonthlyStatus::Closing::ValidationErrorNotifying.call(user_id: user.id, pending: [ { month: 8, year: 2026 } ])
      ).to be_a(Solid::Success)
      expect(
        Core::Settlement::Processing::FailureNotifying.call(user_id: user.id, month: 8, year: 2026, failures: [ { kind: "expense", type: :invalid_input } ])
      ).to be_a(Solid::Success)
    end

    it "propagates nested notification persist failures" do
      allow(Notification).to receive(:create).and_return(failure(:notification_creation_failed, errors:))
      allow(Notification).to receive(:create_all).and_return(failure(:notifications_creation_failed, errors:))

      expect(
        Core::MonthlyStatus::Closing::UnexpectedErrorNotifying.call(user_id: user.id, type: :unexpected, error: "boom").type
      ).to eq(:notification_creation_failed)
      expect(
        Core::Settlement::Processing::UnexpectedErrorNotifying.call(user_id: user.id, month: 8, year: 2026, type: :unexpected, error: "boom").type
      ).to eq(:notification_creation_failed)
      expect(
        Core::Settlement::Processing::ValidationErrorNotifying.call(user_id: user.id, month: 8, year: 2026, type: :invalid_input).type
      ).to eq(:notification_creation_failed)
      expect(
        Core::MonthlyStatus::Closing::ValidationErrorNotifying.call(user_id: user.id, pending: [ { month: 8, year: 2026 } ]).type
      ).to eq(:notifications_creation_failed)
      expect(
        Core::Settlement::Processing::FailureNotifying.call(user_id: user.id, month: 8, year: 2026, failures: [ { kind: "expense", type: :invalid_input } ]).type
      ).to eq(:notifications_creation_failed)
    end
  end

  describe "settlement processing and monthly closing" do
    it "rejects creating a month when a later month is already closed" do
      calls = 0
      allow(MonthlyStatus::Adapters.repository).to receive(:exists_closed_after?).and_wrap_original do |original, **kwargs|
        calls += 1
        calls > 1 ? true : original.call(**kwargs)
      end

      travel_to(Date.new(2026, 8, 29)) do
        result = Core::Settlement::Processing.call(user_id: user.id, month: 8, year: 2026, reference_date: Date.new(2026, 8, 28))

        expect(result.type).to eq(:later_month_closed)
      end
    end

    it "records item failures that have no input payload" do
      account = create(:account, :bank_account, user:, current_balance: 1000)
      create(:transaction, user:, account:, value: 10, starts_on: Date.new(2026, 8, 11))
      allow(Core::Transaction::Settlement::Creation).to receive(:call).and_return(failure(:transaction_not_found))

      travel_to(Date.new(2026, 8, 29)) do
        result = Core::Settlement::Processing.call(user_id: user.id, month: 8, year: 2026, reference_date: Date.new(2026, 8, 28))

        expect(result).to be_a(Solid::Success)
        expect(result.value[:failures]).not_to be_empty
      end
    end

    it "fails monthly closing create persist and records closing failures" do
      allow(MonthlyStatus::Adapters.repository).to receive(:find).and_return(failure(:monthly_status_not_found))
      allow(MonthlyStatus::Adapters.repository).to receive(:exists_closed_after?).and_return(false)
      allow(MonthlyStatus::Adapters.repository).to receive(:create).and_return(failure(:monthly_status_creation_failed, errors:))

      travel_to(Date.new(2026, 9, 10)) do
        expect(Core::MonthlyStatus::Closing.call(user_id: user.id, month: 8, year: 2026).type).to eq(:monthly_status_creation_failed)
        expect(Core::MonthlyStatus::OpenMonths::Closing.call(user_id: user.id).type).to eq(:monthly_status_creation_failed)
      end
    end

    it "treats a closing Failure as a pending failure item" do
      monthly_status = create(:monthly_status, user:, month: 8, year: 2026)
      allow(Core::MonthlyStatus::Closing).to receive(:call).and_return(failure(:monthly_status_closing_failed))
      allow(Core::MonthlyStatus::Closing::ValidationErrorNotifying).to receive(:call).and_return(Solid::Success(:notifications_created))

      travel_to(Date.new(2026, 9, 10)) do
        Core::MonthlyStatus::OpenMonths::Closing.call(user_id: user.id)
      end

      expect(Core::MonthlyStatus::Closing::ValidationErrorNotifying).to have_received(:call).with(
        hash_including(
          pending: [
            hash_including(month: 8, year: 2026, monthly_status_id: monthly_status.id, failure: :monthly_status_closing_failed)
          ]
        )
      )
    end
  end
end
