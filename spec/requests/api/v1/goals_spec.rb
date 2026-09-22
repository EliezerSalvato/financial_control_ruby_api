require "rails_helper"

RSpec.describe "API::V1::Goals", type: :request do
  let(:user) { create(:user, :verified) }
  let(:headers) { auth_headers_for(user) }
  let(:account) { create(:account, user:, name: "Checking") }
  let(:credit_card) { create(:credit_card, user:, name: "Nubank", closing_day: 10, due_day: 17) }
  let(:destination_account) { create(:account, user:, name: "Savings") }

  def list_goals(query = {}, request_headers = headers)
    get "/api/v1/goals", params: query, headers: request_headers
  end

  def item_attributes(payload = response.parsed_body)
    payload.fetch("data").map { |item| item.fetch("attributes") }
  end

  def descriptions
    item_attributes.map { |item| item.fetch("description") }
  end

  describe "GET /api/v1/goals" do
    context "when authenticated" do
      it "returns income, expense, and transfer transactions with category and tag ids" do
        housing = create(:category, user:, name: "Moradia")
        salary = create(:category, user:, name: "Salário")
        transfers = create(:category, user:, name: "Transferências")
        casa = create(:tag, user:, name: "Casa")
        lazer = create(:tag, user:, name: "Lazer")
        poupanca = create(:tag, user:, name: "Poupança")
        expense = create(
          :transaction,
          user:,
          account:,
          category: housing,
          tags: [ lazer, casa ],
          description: "Aluguel",
          starts_on: Date.new(2026, 9, 5),
          value: 100
        )
        income = create(
          :transaction,
          :income,
          user:,
          account:,
          category: salary,
          description: "Salário",
          starts_on: Date.new(2026, 9, 1),
          value: 3000
        )
        transfer = create(
          :transaction,
          :transfer,
          user:,
          category: transfers,
          source_account: account,
          destination_account:,
          tags: [ poupanca ],
          description: "Poupança",
          starts_on: Date.new(2026, 9, 10),
          value: 200
        )

        list_goals(month: 9, year: 2026)

        by_id = item_attributes.index_by { |item| item.fetch("id") }

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["type"]).to eq("collection")
        expect(response.parsed_body.dig("data", 0, "type")).to eq("goal_transaction")
        expect(by_id.keys).to contain_exactly(income.id, expense.id, transfer.id)
        expect(descriptions).to eq(%w[Salário Aluguel Poupança])
        expect(by_id.fetch(expense.id)).to include(
          "kind" => "expense",
          "description" => "Aluguel",
          "recurrence_type" => "one_time",
          "value" => "100.0",
          "first_recurrence_on" => "2026-09-05",
          "current_recurrence_on" => "2026-09-05",
          "ends_on" => nil,
          "category_id" => housing.id,
          "tag_ids" => contain_exactly(casa.id, lazer.id)
        )
        expect(by_id.fetch(income.id)).to include(
          "kind" => "income",
          "description" => "Salário",
          "category_id" => salary.id,
          "tag_ids" => []
        )
        expect(by_id.fetch(transfer.id)).to include(
          "kind" => "transfer_between_accounts",
          "description" => "Poupança",
          "category_id" => transfers.id,
          "tag_ids" => [ poupanca.id ]
        )
      end

      it "uses the latest recurrence that starts on or before the period closing date" do
        housing = create(:category, user:, name: "Moradia")
        transaction = create(
          :transaction,
          :recurring,
          user:,
          account:,
          category: housing,
          description: "Internet",
          starts_on: Date.new(2026, 1, 10),
          value: 80
        )
        create(:transaction_recurrence, financial_transaction: transaction, starts_on: Date.new(2026, 9, 10), value: 90)
        create(:transaction_recurrence, financial_transaction: transaction, starts_on: Date.new(2026, 10, 10), value: 100)

        list_goals(month: 9, year: 2026)

        expect(item_attributes.first).to include(
          "id" => transaction.id,
          "value" => "90.0",
          "first_recurrence_on" => "2026-01-10",
          "current_recurrence_on" => "2026-09-10",
          "recurrence_type" => "recurring"
        )
      end

      it "places a credit card purchase on the billing cycle, not the civil month of the purchase" do
        shopping = create(:category, user:, name: "Compras")
        create(
          :transaction,
          :with_credit_card,
          user:,
          credit_card:,
          category: shopping,
          description: "Grocery",
          starts_on: Date.new(2026, 8, 15),
          value: 250
        )

        list_goals(month: 8, year: 2026)

        expect(descriptions).to eq([])

        list_goals(month: 9, year: 2026)

        expect(item_attributes.first).to include(
          "kind" => "expense",
          "description" => "Grocery",
          "value" => "250.0",
          "first_recurrence_on" => "2026-08-15",
          "current_recurrence_on" => "2026-08-15",
          "category_id" => shopping.id
        )
      end

      it "returns an empty collection when there are no matching transactions" do
        list_goals(month: 9, year: 2026)

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["data"]).to eq([])
      end

      it "returns 422 when month is missing" do
        list_goals(year: 2026)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "month")).to be_present
      end

      it "returns 422 when year is missing" do
        list_goals(month: 9)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "year")).to be_present
      end

      it "returns 422 for an invalid month" do
        list_goals(month: 13, year: 2026)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "month")).to be_present
      end

      it "returns 422 for month 0" do
        list_goals(month: 0, year: 2026)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "month")).to be_present
      end

      it "returns 422 for year 0" do
        list_goals(month: 9, year: 0)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "year")).to be_present
      end

      it "returns 422 for a year above 9999" do
        list_goals(month: 9, year: 10_000)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "year")).to be_present
      end
    end

    context "when unauthenticated" do
      subject { list_goals({ month: 9, year: 2026 }, {}) }

      it_behaves_like "an unauthorized API request"
    end
  end
end
