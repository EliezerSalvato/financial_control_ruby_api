require "rails_helper"

RSpec.describe Transaction::Import::PersistRowJob, type: :job do
  include ActiveJob::TestHelper
  include ActiveSupport::Testing::TimeHelpers

  let(:user) { create(:user, :verified) }
  let(:account) { create(:account, user:) }
  let!(:category) { create(:category, user:) }
  let(:import_id) { SecureRandom.uuid_v7 }
  let(:stream) { TransactionImportChannel.broadcasting_for(user.id) }
  let(:row) do
    {
      row: 4, create: true, source_key: "2026-10-01|Coffee|5.00", date: "2026-10-01", description: "Coffee", amount: "5.00",
      kind: "expense", payment_method: "pix", account_id: account.id, recurrence_type: "one_time", category_id: category.id
    }
  end

  around { |example| travel_to(Date.new(2026, 10, 3)) { example.run } }

  def perform(attributes = row, user_id: user.id)
    described_class.perform_now(user_id:, import_id:, row: attributes)
  end

  def broadcast_payloads
    ActionCable.server.pubsub.broadcasts(stream).map { |message| JSON.parse(message).deep_symbolize_keys }
  end

  it "creates the transaction and broadcasts it" do
    expect { perform }.to change(Transaction::Record, :count).by(1)

    transaction = Transaction::Record.find_by!(user_id: user.id)

    expect(transaction).to have_attributes(
      description: "Coffee", kind: "expense", payment_method: "pix", recurrence_type: "one_time",
      category_id: category.id, source_key: "2026-10-01|Coffee|5.00"
    )
    expect(transaction.recurrences.first).to have_attributes(starts_on: Date.new(2026, 10, 1), value: 5)
    expect(transaction.for_account.account_id).to eq(account.id)
    expect(broadcast_payloads).to eq(
      [ { import_id:, stage: "import", row: 4, status: "created", transaction_id: transaction.id } ]
    )
  end

  context "with an installment row" do
    let(:card) { create(:credit_card, user:) }
    let(:installment_row) do
      row.except(:account_id).merge(
        payment_method: "credit_card", credit_card_id: card.id, recurrence_type: "installment",
        limit_consumption_type: "monthly", installments_count: 3
      )
    end

    it "derives ends_on from the installments count" do
      expect { perform(installment_row) }.to change(Transaction::Record, :count).by(1)

      transaction = Transaction::Record.find_by!(user_id: user.id)

      expect(transaction).to have_attributes(recurrence_type: "installment", installments_count: 3, ends_on: Date.new(2026, 12, 1))
      expect(transaction.for_credit_card.limit_consumption_type).to eq("monthly")
    end

    it "requires the installments count and the limit consumption type" do
      expect { perform(installment_row.except(:installments_count, :limit_consumption_type)) }.not_to change(Transaction::Record, :count)

      expect(broadcast_payloads.first).to include(status: "error")
      expect(broadcast_payloads.first[:error]).to include("Installments count", "Limit consumption type")
    end

    it "requires only the installments count for account payments" do
      perform(installment_row.except(:credit_card_id, :limit_consumption_type).merge(payment_method: "pix", account_id: account.id))

      expect(Transaction::Record.find_by!(user_id: user.id).installments_count).to eq(3)
    end

    it "rejects an installments count of one" do
      expect { perform(installment_row.merge(installments_count: 1)) }.not_to change(Transaction::Record, :count)
    end
  end

  it "rejects installment fields on rows that are not installments" do
    expect { perform(row.merge(installments_count: 3, limit_consumption_type: "upfront")) }.not_to change(Transaction::Record, :count)

    expect(broadcast_payloads.first).to include(status: "error")
  end

  it "ignores rows marked with create false" do
    expect { perform(row.merge(create: false)) }.not_to change(Transaction::Record, :count)

    expect(broadcast_payloads).to eq([ { import_id:, stage: "import", row: 4, status: "ignored" } ])
  end

  it "creates the category and tags that do not exist yet, reusing the ones that do" do
    existing_tag = create(:tag, user:, name: "Daily")

    expect {
      perform(row.except(:category_id).merge(category_name: "Leisure", tag_names: [ "daily", "Fun" ], tag_ids: [ create(:tag, user:).id ]))
    }.to change(Category::Record, :count).by(1).and change(Tag::Record, :count).by(1 + 1)

    transaction = Transaction::Record.find_by!(user_id: user.id)

    expect(transaction.category.name).to eq("Leisure")
    expect(transaction.category.color).to match(Core::Color::FORMAT)
    expect(transaction.taggings.map(&:tag).map(&:name)).to include("Daily", "Fun")
    expect(transaction.taggings.map(&:tag_id)).to include(existing_tag.id)
  end

  it "reuses an existing category found by name" do
    expect { perform(row.except(:category_id).merge(category_name: category.name.upcase)) }.not_to change(Category::Record, :count)

    expect(Transaction::Record.find_by!(user_id: user.id).category_id).to eq(category.id)
  end

  it "creates credit card transactions" do
    card = create(:credit_card, user:)

    perform(row.except(:account_id).merge(payment_method: "credit_card", credit_card_id: card.id))

    expect(Transaction::Record.find_by!(user_id: user.id).for_credit_card.credit_card_id).to eq(card.id)
  end

  it "creates recurring and installment transactions" do
    perform(row.merge(recurrence_type: "installment", installments_count: 2, source_key: "a"))
    perform(row.merge(recurrence_type: "recurring", source_key: "b"))

    expect(Transaction::Record.where(user_id: user.id).pluck(:recurrence_type)).to contain_exactly("installment", "recurring")
  end

  it "defaults the recurrence to one time" do
    perform(row.except(:recurrence_type))

    expect(Transaction::Record.find_by!(user_id: user.id)).to be_one_time
  end

  it "skips rows whose source key already exists" do
    create(:transaction, user:, account:, category:, source_key: row[:source_key])

    expect { perform }.not_to change(Transaction::Record, :count)

    expect(broadcast_payloads).to eq([ { import_id:, stage: "import", row: 4, status: "skip" } ])
  end

  it "skips rows when the unique index catches a concurrent import" do
    allow(Transaction::Adapters.repository).to receive(:exists_by_source_key?).and_return(false)
    create(:transaction, user:, account:, category:, source_key: row[:source_key])

    expect { perform }.not_to change(Transaction::Record, :count)

    expect(broadcast_payloads.first).to include(status: "skip")
  end

  it "imports rows without a source key" do
    expect { perform(row.except(:source_key)) }.to change(Transaction::Record, :count).by(1)
  end

  it "broadcasts an error when the category is missing" do
    expect { perform(row.except(:category_id)) }.not_to change(Transaction::Record, :count)

    expect(broadcast_payloads).to eq(
      [ { import_id:, stage: "import", row: 4, status: "error", error: "Category can't be blank" } ]
    )
  end

  it "broadcasts the transaction validation errors in the user's locale and rolls back created categories" do
    user.update!(configs: { "locale" => "pt-BR" })

    expect {
      perform(row.except(:category_id).merge(category_name: "Leisure", account_id: create(:account).id))
    }.not_to change { [ Transaction::Record.count, Category::Record.count ] }

    expect(broadcast_payloads.first).to include(status: "error", error: a_string_including("não foi encontrada"))
  end

  it "broadcasts an error when the account belongs to another user" do
    perform(row.merge(account_id: create(:account).id))

    expect(broadcast_payloads.first).to include(status: "error", error: "Account was not found")
  end

  it "does not retry validation failures" do
    expect { perform(row.merge(date: nil)) }.not_to have_enqueued_job
  end

  it "broadcasts an error when the user no longer exists" do
    user_id = SecureRandom.uuid_v7

    perform(row, user_id:)

    payload = JSON.parse(ActionCable.server.pubsub.broadcasts(TransactionImportChannel.broadcasting_for(user_id)).first)

    expect(payload).to include("status" => "error", "error" => "Unexpected error while processing this row")
  end

  it "retries unexpected exceptions and broadcasts an error once they are exhausted" do
    allow(Transaction).to receive(:import_row).and_raise(StandardError, "boom")

    expect { perform }.to have_enqueued_job(described_class)

    perform_enqueued_jobs(only: described_class) { perform }

    expect(broadcast_payloads.last).to eq(
      import_id:, stage: "import", row: 4, status: "error", error: "Unexpected error while processing this row"
    )
  end
end
