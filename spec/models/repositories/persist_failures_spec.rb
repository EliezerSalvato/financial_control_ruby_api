require "rails_helper"

RSpec.describe "repository persist failures" do
  let(:user) { create(:user, :verified) }
  let(:user_entity) { User::Mapper.to_entity(user) }
  let(:errors) { Core::Errors.new(base: [ "invalid" ]) }

  def fail_save(record_class)
    allow_any_instance_of(record_class).to receive(:save).and_return(false)
  end

  def fail_update(record_class)
    allow_any_instance_of(record_class).to receive(:update).and_return(false)
  end

  def fail_destroy(record_class)
    allow_any_instance_of(record_class).to receive(:destroy).and_return(false)
  end

  def fail_update_all(scope)
    allow(scope).to receive(:update_all).and_raise(ActiveRecord::ActiveRecordError)
  end

  describe Account::Repository::Adapters::ActiveRecord do
    it "returns invalid_filters when pagination raises" do
      allow(Pagination).to receive(:paginate).and_raise(ArgumentError)

      result = described_class.list(user: user_entity, filters: {}, sorting: "name asc", page: 1, per_page: 25)

      expect(result).to be_a(Solid::Failure)
      expect(result.type).to eq(:invalid_filters)
    end

    it "returns Failure when create does not persist" do
      fail_save(Account::Record)

      result = described_class.create(user: user_entity, attributes: { name: "Wallet", kind: "cash", color: "#3B82F6" })

      expect(result.type).to eq(:account_creation_failed)
    end

    it "returns Failure when update does not persist" do
      account = Account::Mapper.to_entity(create(:account, user:))
      fail_update(Account::Record)

      result = described_class.update(account:, attributes: { name: "Cash" })

      expect(result.type).to eq(:account_update_failed)
    end

    it "returns Failure when destroy does not persist" do
      account = Account::Mapper.to_entity(create(:account, user:))
      fail_destroy(Account::Record)

      result = described_class.destroy(account:)

      expect(result.type).to eq(:account_destruction_failed)
    end

    it "returns Failure when a balance adjustment update fails" do
      account = Account::Mapper.to_entity(create(:account, user:, current_balance: 10))
      fail_update(Account::Record)

      result = described_class.adjust_balance(
        account:,
        amount: BigDecimal("5"),
        operation: Core::Account::BalanceOperation::ADD
      )

      expect(result.type).to eq(:account_balance_adjustment_failed)
    end
  end

  describe Category::Repository::Adapters::ActiveRecord do
    it "returns invalid_filters when pagination raises" do
      allow(Pagination).to receive(:paginate).and_raise(ArgumentError)

      expect(described_class.list(user: user_entity, filters: {}, sorting: "name asc", page: 1, per_page: 25).type).to eq(:invalid_filters)
    end

    it "returns Failure when create does not persist" do
      fail_save(Category::Record)

      expect(described_class.create(user: user_entity, attributes: { name: "Food", color: "#3B82F6" }).type).to eq(:category_creation_failed)
    end

    it "returns Failure when update does not persist" do
      category = Category::Mapper.to_entity(create(:category, user:))
      fail_update(Category::Record)

      expect(described_class.update(category:, attributes: { name: "Groceries" }).type).to eq(:category_update_failed)
    end

    it "returns Failure when destroy does not persist" do
      category = Category::Mapper.to_entity(create(:category, user:))
      fail_destroy(Category::Record)

      expect(described_class.destroy(category:).type).to eq(:category_destruction_failed)
    end
  end

  describe Institution::Repository::Adapters::ActiveRecord do
    it "returns invalid_filters when pagination raises" do
      allow(Pagination).to receive(:paginate).and_raise(ArgumentError)

      expect(described_class.list(user: user_entity, filters: {}, sorting: "name asc", page: 1, per_page: 25).type).to eq(:invalid_filters)
    end

    it "returns Failure when create does not persist" do
      fail_save(Institution::Record)

      expect(described_class.create(user: user_entity, attributes: { name: "Nubank", logo_key: "nubank" }).type).to eq(:institution_creation_failed)
    end

    it "returns Failure when update does not persist" do
      institution = Institution::Mapper.to_entity(create(:institution, user:))
      fail_update(Institution::Record)

      expect(described_class.update(institution:, attributes: { name: "Bank" }).type).to eq(:institution_update_failed)
    end

    it "returns Failure when destroy does not persist" do
      institution = Institution::Mapper.to_entity(create(:institution, user:))
      fail_destroy(Institution::Record)

      expect(described_class.destroy(institution:).type).to eq(:institution_destruction_failed)
    end
  end

  describe Tag::Repository::Adapters::ActiveRecord do
    it "returns invalid_filters when pagination raises" do
      allow(Pagination).to receive(:paginate).and_raise(ArgumentError)

      expect(described_class.list(user: user_entity, filters: {}, sorting: "name asc", page: 1, per_page: 25).type).to eq(:invalid_filters)
    end

    it "returns Failure when create does not persist" do
      fail_save(Tag::Record)

      expect(described_class.create(user: user_entity, attributes: { name: "Trip", color: "#3B82F6" }).type).to eq(:tag_creation_failed)
    end

    it "returns Failure when update does not persist" do
      tag = Tag::Mapper.to_entity(create(:tag, user:))
      fail_update(Tag::Record)

      expect(described_class.update(tag:, attributes: { name: "Travel" }).type).to eq(:tag_update_failed)
    end

    it "returns Failure when destroy does not persist" do
      tag = Tag::Mapper.to_entity(create(:tag, user:))
      fail_destroy(Tag::Record)

      expect(described_class.destroy(tag:).type).to eq(:tag_destruction_failed)
    end
  end

  describe CreditCard::Repository::Adapters::ActiveRecord do
    let(:institution) { create(:institution, user:) }
    let(:account) { create(:account, :bank_account, user:, institution:) }

    it "returns invalid_filters when pagination raises" do
      allow(Pagination).to receive(:paginate).and_raise(ArgumentError)

      expect(described_class.list(user: user_entity, filters: {}, sorting: "name asc", page: 1, per_page: 25).type).to eq(:invalid_filters)
    end

    it "returns Failure when create does not persist" do
      fail_save(CreditCard::Record)

      result = described_class.create(
        user: user_entity,
        attributes: {
          institution_id: institution.id,
          default_payment_account_id: account.id,
          name: "Platinum",
          total_limit: 1000,
          available_limit: 1000,
          closing_day: 10,
          due_day: 17,
          network: "mastercard"
        }
      )

      expect(result.type).to eq(:credit_card_creation_failed)
    end

    it "returns Failure when update does not persist" do
      credit_card = CreditCard::Mapper.to_entity(create(:credit_card, user:, institution:, default_payment_account: account))
      fail_update(CreditCard::Record)

      expect(described_class.update(credit_card:, attributes: { name: "Gold" }).type).to eq(:credit_card_update_failed)
    end

    it "returns Failure when destroy does not persist" do
      credit_card = CreditCard::Mapper.to_entity(create(:credit_card, user:, institution:, default_payment_account: account))
      fail_destroy(CreditCard::Record)

      expect(described_class.destroy(credit_card:).type).to eq(:credit_card_destruction_failed)
    end

    it "returns Failure when available limit adjustment update fails" do
      credit_card = CreditCard::Mapper.to_entity(create(:credit_card, user:, institution:, default_payment_account: account, available_limit: 100, total_limit: 1000))
      fail_update(CreditCard::Record)

      result = described_class.adjust_available_limit(
        credit_card:,
        amount: BigDecimal("10"),
        operation: Core::CreditCard::AvailableLimitOperation::ADD
      )

      expect(result.type).to eq(:credit_card_available_limit_adjustment_failed)
    end

    it "falls back to the calendar month when no billing cycle covers the date" do
      credit_card = create(:credit_card, user:, institution:, default_payment_account: account)
      allow(CreditCard::Record).to receive(:find_by_sql).and_return([])

      result = described_class.billing_cycle_month(user: user_entity, credit_card_id: credit_card.id, date: Date.new(2026, 8, 15))

      expect(result).to be_a(Solid::Success)
      expect(result.value).to include(month: 8, year: 2026)
    end
  end

  describe Transaction::Repository::Adapters::ActiveRecord do
    it "returns invalid_filters when pagination raises" do
      allow(Pagination).to receive(:paginate).and_raise(ArgumentError)

      expect(described_class.list(user: user_entity, filters: {}, sorting: "description asc", page: 1, per_page: 25).type).to eq(:invalid_filters)
    end

    it "returns Failure when create does not persist" do
      fail_save(Transaction::Record)

      result = described_class.create(user: user_entity, attributes: { description: "Rent", kind: "expense", payment_method: "pix", recurrence_type: "one_time", status: "pending" })

      expect(result.type).to eq(:transaction_creation_failed)
    end

    it "returns Failure when update does not persist" do
      transaction = Transaction::Mapper.to_entity(create(:transaction, user:))
      fail_update(Transaction::Record)

      expect(described_class.update(transaction:, attributes: { description: "Updated" }).type).to eq(:transaction_update_failed)
    end

    it "returns Failure when destroy does not persist" do
      transaction = Transaction::Mapper.to_entity(create(:transaction, user:))
      fail_destroy(Transaction::Record)

      expect(described_class.destroy(transaction:).type).to eq(:transaction_destruction_failed)
    end
  end

  describe Transaction::ForAccount::Repository::Adapters::ActiveRecord do
    let(:transaction) { Transaction::Mapper.to_entity(create(:transaction, user:)) }
    let(:account) { create(:account, user:) }

    it "returns Failure when create does not persist" do
      fail_save(Transaction::ForAccount::Record)

      expect(described_class.create(transaction:, account_id: account.id).type).to eq(:for_account_creation_failed)
    end

    it "returns Failure when upsert does not persist" do
      fail_save(Transaction::ForAccount::Record)

      expect(described_class.upsert(transaction:, account_id: account.id).type).to eq(:for_account_upsert_failed)
    end

    it "returns Failure when destroy does not persist" do
      fail_destroy(Transaction::ForAccount::Record)

      expect(described_class.destroy(transaction:).type).to eq(:for_account_destruction_failed)
    end
  end

  describe Transaction::ForCreditCard::Repository::Adapters::ActiveRecord do
    let(:transaction) { Transaction::Mapper.to_entity(create(:transaction, :with_credit_card, user:)) }
    let(:credit_card) { create(:credit_card, user:) }

    it "returns Failure when create does not persist" do
      fail_save(Transaction::ForCreditCard::Record)

      expect(described_class.create(transaction:, credit_card_id: credit_card.id, limit_consumption_type: "monthly").type).to eq(:for_credit_card_creation_failed)
    end

    it "returns Failure when upsert does not persist" do
      fail_save(Transaction::ForCreditCard::Record)

      expect(described_class.upsert(transaction:, credit_card_id: credit_card.id, limit_consumption_type: "monthly").type).to eq(:for_credit_card_upsert_failed)
    end

    it "returns Failure when destroy does not persist" do
      fail_destroy(Transaction::ForCreditCard::Record)

      expect(described_class.destroy(transaction:).type).to eq(:for_credit_card_destruction_failed)
    end
  end

  describe Transaction::ForTransferBetweenAccounts::Repository::Adapters::ActiveRecord do
    let(:transaction) { Transaction::Mapper.to_entity(create(:transaction, :transfer, user:)) }
    let(:source) { create(:account, user:) }
    let(:destination) { create(:account, user:) }

    it "returns Failure when create does not persist" do
      fail_save(Transaction::ForTransferBetweenAccounts::Record)

      expect(described_class.create(transaction:, source_account_id: source.id, destination_account_id: destination.id).type).to eq(:for_transfer_between_accounts_creation_failed)
    end

    it "returns Failure when upsert does not persist" do
      fail_save(Transaction::ForTransferBetweenAccounts::Record)

      expect(described_class.upsert(transaction:, source_account_id: source.id, destination_account_id: destination.id).type).to eq(:for_transfer_between_accounts_upsert_failed)
    end

    it "returns Failure when destroy does not persist" do
      fail_destroy(Transaction::ForTransferBetweenAccounts::Record)

      expect(described_class.destroy(transaction:).type).to eq(:for_transfer_between_accounts_destruction_failed)
    end
  end

  describe Transaction::Recurrence::Repository::Adapters::ActiveRecord do
    let(:transaction) { Transaction::Mapper.to_entity(create(:transaction, user:)) }

    it "returns Failure when create does not persist" do
      fail_save(Transaction::Recurrence::Record)

      expect(described_class.create(transaction:, starts_on: Date.new(2026, 8, 11), value: 10).type).to eq(:recurrence_creation_failed)
    end

    it "returns Failure when no recurrence exists for find_latest" do
      orphan = Transaction::Mapper.to_entity(create(:transaction, user:, with_links: false))

      expect(described_class.find_latest(transaction: orphan).type).to eq(:recurrence_not_found)
    end

    it "returns Failure when update does not persist" do
      recurrence = transaction.recurrences.first
      fail_update(Transaction::Recurrence::Record)

      expect(described_class.update(recurrence:, attributes: { value: 20 }).type).to eq(:recurrence_update_failed)
    end

    it "returns Failure when destroy_after cannot destroy a record" do
      create(:transaction_recurrence, financial_transaction: Transaction::Record.find(transaction.id), starts_on: Date.new(2026, 9, 11), value: 10)
      fail_destroy(Transaction::Recurrence::Record)

      expect(described_class.destroy_after(transaction:, starts_on: Date.new(2026, 8, 11)).type).to eq(:recurrence_destruction_failed)
    end
  end

  describe Transaction::Tagging::Repository::Adapters::ActiveRecord do
    it "returns Failure when a tagging is not persisted" do
      transaction = Transaction::Mapper.to_entity(create(:transaction, user:))
      tag = create(:tag, user:)
      allow(Transaction::Tagging::Record).to receive(:create_or_find_by).and_return(Transaction::Tagging::Record.new)

      expect(described_class.sync(transaction:, tag_ids: [ tag.id ]).type).to eq(:taggings_replace_failed)
    end
  end

  describe Transaction::Settlement::Repository::Adapters::ActiveRecord do
    it "returns Failure when create! is invalid" do
      record = Transaction::Settlement::Record.new
      record.errors.add(:base, "invalid")
      allow(Transaction::Settlement::Record).to receive(:create!).and_raise(ActiveRecord::RecordInvalid.new(record))

      result = described_class.create(
        transaction_id: UUID.generate,
        occurred_on: Date.new(2026, 8, 11),
        settled_on: Date.new(2026, 8, 11),
        value: 10,
        installment_number: nil,
        account_id: UUID.generate
      )

      expect(result.type).to eq(:transaction_settlement_creation_failed)
    end
  end

  describe CreditCard::InvoiceSettlement::Repository::Adapters::ActiveRecord do
    it "returns Failure when create! is invalid" do
      record = CreditCard::InvoiceSettlement::Record.new
      record.errors.add(:base, "invalid")
      allow(CreditCard::InvoiceSettlement::Record).to receive(:create!).and_raise(ActiveRecord::RecordInvalid.new(record))

      result = described_class.create(
        credit_card_id: UUID.generate,
        payment_account_id: UUID.generate,
        opening_date: Date.new(2026, 8, 1),
        closing_date: Date.new(2026, 8, 10),
        due_date: Date.new(2026, 8, 17),
        total_value: 10,
        released_limit: 10,
        settled_on: Date.new(2026, 8, 17)
      )

      expect(result.type).to eq(:credit_card_invoice_settlement_creation_failed)
    end
  end

  describe MonthlyStatus::Repository::Adapters::ActiveRecord do
    it "returns Failure when create does not persist" do
      fail_save(MonthlyStatus::Record)

      expect(described_class.create(user_id: user.id, month: 8, year: 2026).type).to eq(:monthly_status_creation_failed)
    end
  end

  describe Notification::Repository::Adapters::ActiveRecord do
    it "returns Failure when create does not persist" do
      fail_save(Notification::Record)

      expect(described_class.create(attributes: { user_id: user.id, kind: "system", title: "Hi" }).type).to eq(:notification_creation_failed)
    end

    it "returns Failure when mark_as_read does not persist" do
      notification = Notification::Mapper.to_entity(create(:notification, user:))
      fail_update(Notification::Record)

      expect(described_class.mark_as_read(notification:, read_at: Time.current).type).to eq(:notification_mark_as_read_failed)
    end
  end

  describe User::Repository::Adapters::ActiveRecord do
    it "returns Failure when create does not persist" do
      fail_save(User::Record)

      result = described_class.create(first_name: "Jane", last_name: "Doe", email: "jane-persist@example.com", password: "password123", password_confirmation: "password123")

      expect(result.type).to eq(:user_creation_failed)
    end

    it "returns Failure when mark_as_verified does not persist" do
      fail_update(User::Record)

      expect(described_class.mark_as_verified(user: user_entity).type).to eq(:mark_user_as_verified_failed)
    end

    it "returns Failure when change_email_and_mark_as_not_verified does not persist" do
      fail_update(User::Record)

      expect(described_class.change_email_and_mark_as_not_verified(user: user_entity, new_email: "new@example.com").type).to eq(:change_email_and_mark_as_not_verified_failed)
    end

    it "returns Failure when update_password does not persist" do
      fail_update(User::Record)

      expect(described_class.update_password(user: user_entity, password: "password456", password_confirmation: "password456").type).to eq(:password_update_failed)
    end

    it "returns Failure when update_profile does not persist" do
      fail_update(User::Record)

      expect(described_class.update_profile(user: user_entity, first_name: "Jane").type).to eq(:profile_update_failed)
    end

    it "returns Failure when destroy does not persist" do
      fail_destroy(User::Record)

      expect(described_class.destroy(user: user_entity).type).to eq(:user_destruction_failed)
    end
  end

  describe User::Session::Repository::Adapters::ActiveRecord do
    it "returns Failure when create does not persist" do
      fail_save(User::Session::Record)

      result = described_class.create(user: user_entity, user_agent: "rspec", ip_address: "127.0.0.1", refresh_token: "token", remember_me: false)

      expect(result.type).to eq(:session_creation_failed)
    end

    it "returns Failure when revoke_all_by raises" do
      relation = User::Session::Record.active.where(user_id: user.id)
      allow(User::Session::Record).to receive_message_chain(:active, :where).and_return(relation)
      fail_update_all(relation)

      expect(described_class.revoke_all_by(user_id: user.id).type).to eq(:sessions_revocation_failed)
    end

    it "returns Failure when update_refresh_token does not persist" do
      session = User::Session::Mapper.to_entity(create(:user_session, user:))
      fail_update(User::Session::Record)

      expect(described_class.update_refresh_token(session:, refresh_token: "new", remember_me: false).type).to eq(:refresh_token_update_failed)
    end
  end

  describe User::Email::Confirmation::Repository::Adapters::ActiveRecord do
    it "returns Failure when create does not persist" do
      fail_save(User::Email::Confirmation::Record)

      expect(described_class.create(user: user_entity).type).to eq(:email_confirmation_creation_failed)
    end

    it "returns Failure when invalidate_all_by raises" do
      relation = User::Email::Confirmation::Record.pending.where(user_id: user.id)
      allow(User::Email::Confirmation::Record).to receive_message_chain(:pending, :where).and_return(relation)
      fail_update_all(relation)

      expect(described_class.invalidate_all_by(user_id: user.id).type).to eq(:email_confirmations_invalidation_failed)
    end

    it "returns Failure when mark_as_confirmed does not persist" do
      confirmation = User::Email::Confirmation::Mapper.to_entity(create(:user_email_confirmation, user:))
      fail_update(User::Email::Confirmation::Record)

      expect(described_class.mark_as_confirmed(email_confirmation: confirmation).type).to eq(:mark_email_confirmation_as_confirmed_failed)
    end
  end

  describe User::Password::Reset::Repository::Adapters::ActiveRecord do
    it "returns Failure when create does not persist" do
      fail_save(User::Password::Reset::Record)

      expect(described_class.create(user: user_entity).type).to eq(:password_reset_creation_failed)
    end

    it "returns Failure when invalidate_all_by raises" do
      relation = User::Password::Reset::Record.pending.where(user_id: user.id)
      allow(User::Password::Reset::Record).to receive_message_chain(:pending, :where).and_return(relation)
      fail_update_all(relation)

      expect(described_class.invalidate_all_by(user_id: user.id).type).to eq(:password_resets_invalidation_failed)
    end

    it "returns Failure when mark_as_reset does not persist" do
      password_reset = User::Password::Reset::Mapper.to_entity(create(:user_password_reset, user:))
      fail_update(User::Password::Reset::Record)

      expect(described_class.mark_as_reset(password_reset:).type).to eq(:mark_password_reset_as_reset_failed)
    end
  end
end
