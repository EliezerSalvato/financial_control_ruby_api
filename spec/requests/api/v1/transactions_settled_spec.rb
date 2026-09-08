require "rails_helper"

RSpec.describe "API::V1::Transactions settled", type: :request do
  let(:user) { create(:user, :verified) }
  let(:headers) { auth_headers_for(user) }
  let(:account) { create(:account, user:, name: "Checking") }
  let(:credit_card) { create(:credit_card, user:, name: "Nubank") }
  let(:source_account) { account }
  let(:destination_account) { create(:account, user:, name: "Savings") }

  def list_settled_transactions(query = {}, request_headers = headers)
    get "/api/v1/transactions/settled", params: query, headers: request_headers
  end

  def item_attributes(payload = response.parsed_body)
    payload.fetch("data").map { |item| item.fetch("attributes") }
  end

  def descriptions
    item_attributes.map { |item| item.fetch("description") }
  end

  def settle!(transaction, occurred_on:, settled_on: occurred_on, value: nil, installment_number: nil, trait: :for_account)
    create(
      :transaction_settlement,
      trait,
      financial_transaction: transaction,
      occurred_on:,
      settled_on:,
      value: value || transaction.recurrences.min_by(&:starts_on).value,
      installment_number:
    )
  end

  def settle_one_of_each_type
    account_transaction = create(
      :transaction,
      :active,
      user:,
      account:,
      description: "Rent",
      starts_on: Date.new(2026, 8, 11),
      value: 100
    )
    credit_card_transaction = create(
      :transaction,
      :with_credit_card,
      :active,
      user:,
      credit_card:,
      description: "Grocery",
      starts_on: Date.new(2026, 8, 1),
      value: 250
    )
    transfer = create(
      :transaction,
      :transfer,
      :active,
      user:,
      source_account:,
      destination_account:,
      description: "Move to savings",
      starts_on: Date.new(2026, 8, 11),
      value: 150
    )
    settle!(account_transaction, occurred_on: Date.new(2026, 8, 11))
    settle!(credit_card_transaction, occurred_on: Date.new(2026, 8, 1), trait: :for_credit_card)
    settle!(transfer, occurred_on: Date.new(2026, 8, 11), value: 150, trait: :for_transfer)
  end

  describe "GET /api/v1/transactions/settled" do
    context "when authenticated" do
      it "returns account, credit card, and transfer occurrences settled in the given month" do
        account_transaction = create(
          :transaction,
          :active,
          user:,
          account:,
          description: "Rent",
          starts_on: Date.new(2026, 8, 11),
          value: 100
        )
        credit_card_transaction = create(
          :transaction,
          :with_credit_card,
          :active,
          user:,
          credit_card:,
          description: "Grocery",
          starts_on: Date.new(2026, 8, 1),
          value: 250
        )
        transfer = create(
          :transaction,
          :transfer,
          :active,
          user:,
          source_account:,
          destination_account:,
          description: "Move to savings",
          starts_on: Date.new(2026, 8, 11),
          value: 150
        )
        account_settlement = settle!(account_transaction, occurred_on: Date.new(2026, 8, 11), settled_on: Date.new(2026, 8, 12))
        card_settlement = settle!(
          credit_card_transaction,
          occurred_on: Date.new(2026, 8, 1),
          trait: :for_credit_card
        )
        transfer_settlement = settle!(
          transfer,
          occurred_on: Date.new(2026, 8, 11),
          value: 150,
          trait: :for_transfer
        )

        list_settled_transactions(month: 8, year: 2026)

        by_id = item_attributes.index_by { |item| item.fetch("id") }

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["type"]).to eq("collection")
        expect(response.parsed_body.dig("data", 0, "type")).to eq("settled_transaction")
        expect(by_id.keys).to contain_exactly(account_settlement.id, card_settlement.id, transfer_settlement.id)
        expect(by_id.fetch(account_settlement.id)).to include(
          "id" => account_settlement.id,
          "transaction_id" => account_transaction.id,
          "category_id" => account_transaction.category_id,
          "description" => "Rent",
          "kind" => "expense",
          "status" => "active",
          "payment_method" => "pix",
          "recurrence_type" => "one_time",
          "installments_count" => nil,
          "ends_on" => nil,
          "canceled_on" => nil,
          "occurred_on" => "2026-08-11",
          "settled_on" => "2026-08-12",
          "value" => "100.0",
          "installment_number" => nil,
          "account_id" => account.id
        )
        expect(by_id.fetch(account_settlement.id)).not_to have_key("credit_card_id")
        expect(by_id.fetch(card_settlement.id)).to include(
          "transaction_id" => credit_card_transaction.id,
          "description" => "Grocery",
          "payment_method" => "credit_card",
          "occurred_on" => "2026-08-01",
          "value" => "250.0",
          "credit_card_id" => credit_card.id,
          "limit_consumption_type" => "upfront"
        )
        expect(by_id.fetch(card_settlement.id)).not_to have_key("account_id")
        expect(by_id.fetch(transfer_settlement.id)).to include(
          "transaction_id" => transfer.id,
          "kind" => "transfer_between_accounts",
          "payment_method" => nil,
          "source_account_id" => source_account.id,
          "destination_account_id" => destination_account.id
        )
      end

      it "excludes transactions that belong to the month but were not settled" do
        create(:transaction, user:, account:, description: "Pending", starts_on: Date.new(2026, 8, 11))
        settled = create(:transaction, :active, user:, account:, description: "Settled", starts_on: Date.new(2026, 8, 12))
        settle!(settled, occurred_on: Date.new(2026, 8, 12))

        list_settled_transactions(month: 8, year: 2026)

        expect(descriptions).to eq(%w[Settled])
      end

      it "excludes settlements from the previous and next months" do
        july = create(:transaction, :active, user:, account:, description: "July", starts_on: Date.new(2026, 7, 31))
        august = create(:transaction, :active, user:, account:, description: "August", starts_on: Date.new(2026, 8, 15))
        september = create(:transaction, :active, user:, account:, description: "September", starts_on: Date.new(2026, 9, 1))
        settle!(july, occurred_on: Date.new(2026, 7, 31))
        settle!(august, occurred_on: Date.new(2026, 8, 15))
        settle!(september, occurred_on: Date.new(2026, 9, 1))

        list_settled_transactions(month: 8, year: 2026)

        expect(descriptions).to eq(%w[August])
      end

      it "includes settlements on the first and last day of the month" do
        first = create(:transaction, :active, user:, account:, description: "First day", starts_on: Date.new(2026, 8, 1))
        last = create(:transaction, :active, user:, account:, description: "Last day", starts_on: Date.new(2026, 8, 31))
        settle!(first, occurred_on: Date.new(2026, 8, 1))
        settle!(last, occurred_on: Date.new(2026, 8, 31))

        list_settled_transactions(month: 8, year: 2026)

        expect(descriptions).to eq([ "First day", "Last day" ])
      end

      it "includes February 29 on a leap year" do
        leap = create(:transaction, :active, user:, account:, description: "Leap day", starts_on: Date.new(2028, 2, 29))
        march = create(:transaction, :active, user:, account:, description: "Mar 1", starts_on: Date.new(2028, 3, 1))
        settle!(leap, occurred_on: Date.new(2028, 2, 29))
        settle!(march, occurred_on: Date.new(2028, 3, 1))

        list_settled_transactions(month: 2, year: 2028)

        expect(descriptions).to eq([ "Leap day" ])
      end

      it "returns only the requested month occurrence of a recurring transaction" do
        recurring = create(
          :transaction,
          :recurring,
          :active,
          user:,
          account:,
          description: "Salary",
          starts_on: Date.new(2026, 8, 11),
          value: 100
        )
        settle!(recurring, occurred_on: Date.new(2026, 8, 11), installment_number: 1)
        settle!(recurring, occurred_on: Date.new(2026, 9, 11), installment_number: 2)

        list_settled_transactions(month: 8, year: 2026)

        expect(item_attributes).to contain_exactly(
          hash_including(
            "transaction_id" => recurring.id,
            "description" => "Salary",
            "occurred_on" => "2026-08-11",
            "installment_number" => 1,
            "value" => "100.0"
          )
        )
      end

      it "does not return another user's settled transactions" do
        mine = create(:transaction, :active, user:, account:, description: "Mine", starts_on: Date.new(2026, 8, 11))
        settle!(mine, occurred_on: Date.new(2026, 8, 11))
        other = create(:transaction, :active, description: "Other", starts_on: Date.new(2026, 8, 11))
        create(
          :transaction_settlement,
          :for_account,
          financial_transaction: other,
          occurred_on: Date.new(2026, 8, 11)
        )

        list_settled_transactions(month: 8, year: 2026)

        expect(descriptions).to eq(%w[Mine])
      end

      it "orders by occurred_on, then description" do
        later = create(:transaction, :active, user:, account:, description: "Zebra", starts_on: Date.new(2026, 8, 20))
        earlier_b = create(:transaction, :active, user:, account:, description: "Beta", starts_on: Date.new(2026, 8, 11))
        earlier_a = create(:transaction, :active, user:, account:, description: "Alpha", starts_on: Date.new(2026, 8, 11))
        settle!(later, occurred_on: Date.new(2026, 8, 20))
        settle!(earlier_b, occurred_on: Date.new(2026, 8, 11))
        settle!(earlier_a, occurred_on: Date.new(2026, 8, 11))

        list_settled_transactions(month: 8, year: 2026)

        expect(descriptions).to eq(%w[Alpha Beta Zebra])
      end

      it "returns an empty collection when there are no matching settlements" do
        create(:transaction, user:, account:, description: "Pending", starts_on: Date.new(2026, 8, 11))

        list_settled_transactions(month: 8, year: 2026)

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["data"]).to eq([])
      end

      it "returns 422 when month is missing" do
        list_settled_transactions(year: 2026)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "month")).to be_present
      end

      it "returns 422 when year is missing" do
        list_settled_transactions(month: 8)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "year")).to be_present
      end

      it "returns 422 for an invalid month" do
        list_settled_transactions(month: 13, year: 2026)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "month")).to be_present
      end

      it "returns 422 for month 0" do
        list_settled_transactions(month: 0, year: 2026)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "month")).to be_present
      end

      it "returns 422 for year 0" do
        list_settled_transactions(month: 8, year: 0)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "year")).to be_present
      end

      it "returns 422 for a year above 9999" do
        list_settled_transactions(month: 8, year: 10_000)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "year")).to be_present
      end

      it "returns only credit card settlements when type is credit_card" do
        settle_one_of_each_type

        list_settled_transactions(month: 8, year: 2026, type: "credit_card")

        expect(descriptions).to eq(%w[Grocery])
        expect(item_attributes).to contain_exactly(hash_including("credit_card_id" => credit_card.id))
      end

      it "returns only account settlements when type is account" do
        settle_one_of_each_type

        list_settled_transactions(month: 8, year: 2026, type: "account")

        expect(descriptions).to eq(%w[Rent])
        expect(item_attributes).to contain_exactly(hash_including("account_id" => account.id))
      end

      it "returns only transfer settlements when type is transfer_between_accounts" do
        settle_one_of_each_type

        list_settled_transactions(month: 8, year: 2026, type: "transfer_between_accounts")

        expect(descriptions).to eq([ "Move to savings" ])
        expect(item_attributes).to contain_exactly(
          hash_including(
            "source_account_id" => source_account.id,
            "destination_account_id" => destination_account.id
          )
        )
      end

      it "returns all payment targets when type is omitted" do
        settle_one_of_each_type

        list_settled_transactions(month: 8, year: 2026)

        expect(descriptions).to eq([ "Grocery", "Move to savings", "Rent" ])
      end

      it "returns 422 for an invalid type" do
        list_settled_transactions(month: 8, year: 2026, type: "pix")

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "type")).to be_present
      end
    end

    context "when unauthenticated" do
      subject { list_settled_transactions({ month: 8, year: 2026 }, {}) }

      it_behaves_like "an unauthorized API request"
    end
  end
end
