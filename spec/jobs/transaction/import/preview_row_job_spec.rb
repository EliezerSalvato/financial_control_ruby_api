require "rails_helper"

RSpec.describe Transaction::Import::PreviewRowJob, type: :job do
  include ActiveJob::TestHelper

  let(:user) { create(:user, :verified) }
  let(:account) { create(:account, user:) }
  let(:import_id) { SecureRandom.uuid_v7 }
  let(:stream) { TransactionImportChannel.broadcasting_for(user.id) }
  let(:defaults) { { kind: "expense", payment_method: "pix", account_id: account.id, credit_card_id: nil, limit_consumption_type: nil, installments_count: nil } }

  def perform(row_data: data, row: 3, occurrence: 1)
    described_class.perform_now(user_id: user.id, import_id:, row:, data: row_data, occurrence:, defaults:)
  end

  def broadcast_payloads
    ActionCable.server.pubsub.broadcasts(stream).map { |message| JSON.parse(message).deep_symbolize_keys }
  end

  # CsvParsing already renames `title`/`value`; the job receives the parsed hash.
  let(:data) { { "date" => "2026-10-01", "description" => "Ifd*Burger King", "amount" => "25,90" } }

  it "broadcasts the processed row with the defaults and no category" do
    perform

    expect(broadcast_payloads).to eq(
      [
        {
          import_id:, stage: "preview", row: 3, status: "processed",
          data: {
            date: "2026-10-01", description: "Ifd*Burger King", original_description: "Ifd*Burger King", amount: "25.90",
            recurrence_type: "one_time", ends_on: nil, **defaults, category: nil, tags: [],
            source_key: "2026-10-01|Ifd*Burger King|25.90", applied_rules: []
          }
        }
      ]
    )
  end

  context "with installment defaults" do
    let(:defaults) { super().merge(limit_consumption_type: "monthly", installments_count: 3) }

    it "clears them from rows that are not installments" do
      perform

      expect(broadcast_payloads.first[:data]).to include(limit_consumption_type: nil, installments_count: nil)
    end

    it "keeps them on installment rows" do
      perform(row_data: data.merge("recurrence_type" => "installment"))

      expect(broadcast_payloads.first[:data]).to include(limit_consumption_type: "monthly", installments_count: 3)
    end
  end

  it "applies the user's active rules" do
    category = create(:category, user:, name: "food")
    tag = create(:tag, user:, name: "Delivery")
    create(
      :transaction_import_rule, user:, name: "Delivery", position: 1, pattern: "Ifd*",
      effects_attributes: [
        { effect_type: "replace_text", pattern: "Ifd*", replacement: "" }, { effect_type: "set_category", category_id: category.id },
        { effect_type: "add_tags", tag_ids: [ tag.id ] }
      ]
    )
    create(
      :transaction_import_rule, :regex, user:, name: "Installments", position: 2, pattern: "\\bparcela\\b",
      effects_attributes: [ { effect_type: "set_recurrence_type", recurrence_type: "recurring" } ]
    )
    create(:transaction_import_rule, :inactive, user:, name: "Inactive", pattern: "Burger", effects_attributes: [ { effect_type: "add_tags", tag_ids: [ create(:tag, user:).id ] } ])
    create(:transaction_import_rule, name: "Other user", pattern: "Burger", effects_attributes: [ { effect_type: "add_tags", tag_ids: [ create(:tag).id ] } ])
    create(
      :transaction_import_rule, user:, name: "Title only", position: 3, pattern: "Burger", target_column: "title",
      effects_attributes: [ { effect_type: "add_tags", tag_ids: [ create(:tag, user:).id ] } ]
    )

    perform(row_data: data.merge("description" => "Ifd*Burger King Parcela", "tags" => "fun"))

    payload = broadcast_payloads.first[:data]

    expect(payload).to include(
      description: "Burger King Parcela", original_description: "Ifd*Burger King Parcela", recurrence_type: "recurring",
      category: { id: category.id, name: "food", new: false },
      tags: [ { name: "fun", new: true }, { id: tag.id, name: "Delivery", new: false } ],
      applied_rules: [ { id: kind_of(String), name: "Delivery" }, { id: kind_of(String), name: "Installments" } ]
    )
  end

  it "prefers the category and recurrence from the file over the rules" do
    create(
      :transaction_import_rule, user:, pattern: "Burger",
      effects_attributes: [
        { effect_type: "set_category", category_id: create(:category, user:).id },
        { effect_type: "set_recurrence_type", recurrence_type: "recurring" }
      ]
    )

    perform(row_data: data.merge("category" => "Leisure", "recurrence_type" => "installment", "ends_on" => "2027-01-01"))

    expect(broadcast_payloads.first[:data]).to include(
      category: { name: "Leisure", new: true }, recurrence_type: "installment", ends_on: "2027-01-01"
    )
  end

  it "ignores categories and tags from rules that no longer exist, and does not repeat a tag from the file" do
    kept = create(:tag, user:, name: "Kept")
    removed = create(:tag, user:)
    create(
      :transaction_import_rule, user:, pattern: "Burger",
      effects_attributes: [ { effect_type: "add_tags", tag_ids: [ kept.id, removed.id ] }, { effect_type: "set_category", category_id: create(:category, user:).id } ]
    )
    removed.destroy
    allow(Category::Adapters.repository).to receive(:find_by_id).and_return(Solid::Failure(:category_not_found))

    perform(row_data: data.merge("tags" => "kept"))

    expect(broadcast_payloads.first[:data]).to include(category: nil, tags: [ { id: kept.id, name: "Kept", new: false } ])
  end

  it "matches the category from the file with an existing one by name" do
    category = create(:category, user:, name: "Leisure")

    perform(row_data: data.merge("category" => "leisure"))

    expect(broadcast_payloads.first[:data]).to include(category: { id: category.id, name: "Leisure", new: false })
  end

  it "skips rows matched by a rule with a skip effect" do
    create(:transaction_import_rule, user:, pattern: "Burger", effects_attributes: [ { effect_type: "skip" } ])

    perform

    expect(broadcast_payloads).to eq([ { import_id:, stage: "preview", row: 3, status: "skip" } ])
  end

  it "numbers repeated lines with the occurrence" do
    perform(occurrence: 2)

    expect(broadcast_payloads.first.dig(:data, :source_key)).to eq("2026-10-01|Ifd*Burger King|25.90|2")
  end

  it "builds the source key from the description after the rules ran" do
    create(
      :transaction_import_rule, user:, pattern: "Ifd*",
      effects_attributes: [ { effect_type: "replace_text", pattern: "Ifd*", replacement: "" } ]
    )

    perform

    expect(broadcast_payloads.first.dig(:data, :source_key)).to eq("2026-10-01|Burger King|25.90")
  end

  it "skips rows already imported" do
    create(:transaction, user:, account:, source_key: "2026-10-01|Ifd*Burger King|25.90")

    perform

    expect(broadcast_payloads).to eq([ { import_id:, stage: "preview", row: 3, status: "skip" } ])
  end

  it "broadcasts an error for an invalid date" do
    perform(row_data: data.merge("date" => "2026-13-01"))

    expect(broadcast_payloads).to eq(
      [ { import_id:, stage: "preview", row: 3, status: "error", error: "Date must be a valid date in YYYY-MM-DD or DD/MM/YYYY format" } ]
    )
  end

  it "broadcasts an error for an invalid amount in the user's locale" do
    user.update!(configs: { "locale" => "pt-BR" })

    perform(row_data: data.merge("amount" => "abc"))

    expect(broadcast_payloads.first).to include(status: "error", error: a_string_including("valor válido"))
  end

  it "broadcasts an error when the user no longer exists" do
    user_id = SecureRandom.uuid_v7

    described_class.perform_now(user_id:, import_id:, row: 1, data:, occurrence: 1, defaults:)

    payload = JSON.parse(ActionCable.server.pubsub.broadcasts(TransactionImportChannel.broadcasting_for(user_id)).first)

    expect(payload).to include("status" => "error", "error" => "Unexpected error while processing this row")
  end

  it "does not retry a failure" do
    expect { perform(row_data: data.merge("date" => "x")) }.not_to have_enqueued_job
  end

  it "retries unexpected exceptions" do
    allow(Transaction).to receive(:preview_import_row).and_raise(StandardError, "boom")

    expect { perform }.to have_enqueued_job(described_class)
  end

  it "broadcasts an error when the retries are exhausted" do
    allow(Transaction).to receive(:preview_import_row).and_raise(StandardError, "boom")

    perform_enqueued_jobs(only: described_class) { perform }

    expect(broadcast_payloads.last).to eq(
      import_id:, stage: "preview", row: 3, status: "error", error: "Unexpected error while processing this row"
    )
  end
end
