require "rails_helper"

RSpec.describe "API::V1::Transactions", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let(:user) { create(:user, :verified) }
  let(:headers) { auth_headers_for(user) }
  let(:account) { create(:account, user:) }
  let(:category) { create(:category, user:) }
  let(:tag) { create(:tag, user:) }
  let(:credit_card) { create(:credit_card, user:) }
  let(:source_account) { create(:account, user:, name: "Source") }
  let(:destination_account) { create(:account, user:, name: "Destination") }

  def transaction_attributes(payload)
    payload.dig("data", "attributes")
  end

  def transaction_recurrences(payload)
    Array(transaction_attributes(payload)["recurrences"]).map { |item| item.fetch("attributes") }
  end

  def create_params(overrides = {})
    {
      transaction: {
        description: "Grocery",
        kind: "expense",
        payment_method: "pix",
        recurrence_type: "one_time",
        starts_on: "2026-08-11",
        value: 100,
        account_id: account.id,
        category_id: category.id,
        tag_ids: [ tag.id ]
      }.merge(overrides)
    }
  end

  describe "GET /api/v1/transactions" do
    def list_transactions(query = {}, request_headers = headers)
      get "/api/v1/transactions", params: query, headers: request_headers
    end

    context "when authenticated" do
      let!(:expense) { create(:transaction, user:, account:, description: "Grocery", kind: "expense") }
      let!(:income) { create(:transaction, :income, user:, account:, description: "Salary") }
      let!(:other_user_transaction) { create(:transaction, description: "Other") }

      it "returns only the current user's transactions" do
        list_transactions

        ids = response.parsed_body["data"].map { |item| item.dig("attributes", "id") }

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["type"]).to eq("collection")
        expect(ids).to contain_exactly(expense.id, income.id)
        expect(ids).not_to include(other_user_transaction.id)
      end

      it "filters by kind" do
        list_transactions(q: { kind_eq: "income" })

        descriptions = response.parsed_body["data"].map { |item| item.dig("attributes", "description") }

        expect(descriptions).to eq(%w[Salary])
      end

      it "filters by id" do
        list_transactions(q: { id_eq: expense.id })

        ids = response.parsed_body["data"].map { |item| item.dig("attributes", "id") }

        expect(ids).to eq([ expense.id ])
      end

      it "filters by installments_count" do
        create(:transaction, :installment, user:, account:, description: "Installment")

        list_transactions(q: { installments_count_eq: 2 })

        descriptions = response.parsed_body["data"].map { |item| item.dig("attributes", "description") }

        expect(descriptions).to eq(%w[Installment])
      end

      it "filters by status" do
        expense.update!(status: "completed")

        list_transactions(q: { status_eq: "completed" })

        descriptions = response.parsed_body["data"].map { |item| item.dig("attributes", "description") }

        expect(descriptions).to eq(%w[Grocery])
      end

      it "orders by status, created_at desc by default" do
        active_transaction = create(:transaction, :active, user:, account:, description: "Active")
        expense.update_column(:created_at, 2.days.ago)
        income.update_column(:created_at, 1.day.ago)
        active_transaction.update_column(:created_at, 3.days.ago)

        list_transactions

        descriptions = response.parsed_body["data"].map { |item| item.dig("attributes", "description") }

        expect(descriptions).to eq(%w[Salary Grocery Active])
      end

      it "filters by created_at period" do
        expense.update_column(:created_at, Time.zone.parse("2026-01-01 12:00:00"))
        income.update_column(:created_at, Time.zone.parse("2026-08-01 12:00:00"))

        list_transactions(q: { created_at_gteq: "2026-07-01" })

        descriptions = response.parsed_body["data"].map { |item| item.dig("attributes", "description") }

        expect(descriptions).to eq(%w[Salary])
      end

      it "filters by ends_on period" do
        create(:transaction, :installment, user:, account:, description: "Installment")

        list_transactions(q: { ends_on_gteq: "2026-09-01" })

        descriptions = response.parsed_body["data"].map { |item| item.dig("attributes", "description") }

        expect(descriptions).to eq(%w[Installment])
      end

      it "supports custom sorting" do
        expense.update_column(:created_at, 1.day.ago)
        income.update_column(:created_at, 2.days.ago)

        list_transactions(sort: "created_at desc")

        descriptions = response.parsed_body["data"].map { |item| item.dig("attributes", "description") }

        expect(descriptions).to eq(%w[Grocery Salary])
      end

      it "ignores unknown filters" do
        list_transactions(q: { unknown_field_eq: "x" })

        ids = response.parsed_body["data"].map { |item| item.dig("attributes", "id") }

        expect(response).to have_http_status(:ok)
        expect(ids).to contain_exactly(expense.id, income.id)
      end

      it "includes status in the collection" do
        list_transactions

        statuses = response.parsed_body["data"].map { |item| item.dig("attributes", "status") }

        expect(statuses).to all(eq("pending"))
      end

      it "includes recurrences ordered by starts_on and does not load payment targets or tags" do
        tagged = create(:transaction, user:, account:, category:, tags: [ tag ], description: "Tagged")
        create(:transaction_recurrence, financial_transaction: tagged, starts_on: Date.new(2026, 10, 11), value: 80)

        list_transactions

        attributes = response.parsed_body["data"].find { |item| item.dig("attributes", "id") == tagged.id }.fetch("attributes")

        expect(attributes["recurrences"].map { |item| item.dig("attributes", "starts_on") }).to eq(
          %w[2026-08-11 2026-10-11]
        )
        expect(attributes["tag_ids"]).to be_nil
        expect(attributes["account_id"]).to be_nil
      end

      it "includes the current value of each transaction" do
        travel_to(Date.new(2026, 8, 19)) do
          recurring = create(:transaction, :recurring, user:, account:, description: "Rent", starts_on: Date.new(2026, 1, 31), value: 100)
          create(:transaction_recurrence, financial_transaction: recurring, starts_on: Date.new(2026, 8, 31), value: 107)
          create(:transaction_recurrence, financial_transaction: recurring, starts_on: Date.new(2026, 9, 30), value: 120)
          create(:transaction_recurrence, financial_transaction: recurring, starts_on: Date.new(2026, 10, 30), value: 110)

          list_transactions

          values_by_id = response.parsed_body["data"].to_h { |item| [ item.dig("attributes", "id"), item.dig("attributes", "current_value") ] }

          expect(values_by_id[expense.id]).to eq("100.0")
          expect(values_by_id[income.id]).to eq("100.0")
          expect(values_by_id[recurring.id]).to eq("107.0")
        end
      end

      it "paginates the collection" do
        list_transactions(page: 1, per_page: 1)

        meta = response.parsed_body["meta"]

        expect(response.parsed_body["data"].size).to eq(1)
        expect(meta).to include(
          "page" => 1,
          "per_page" => 1,
          "count" => 2,
          "pages" => 2
        )
      end
    end

    context "when unauthenticated" do
      subject { list_transactions({}, {}) }

      it_behaves_like "an unauthorized API request"
    end
  end

  describe "GET /api/v1/transactions/:id" do
    let(:transaction) { create(:transaction, user:, account:, category:, tags: [ tag ], description: "Grocery") }

    def show_transaction(id, request_headers = headers)
      get "/api/v1/transactions/#{id}", headers: request_headers
    end

    context "when authenticated" do
      it "returns the transaction" do
        show_transaction(transaction.id)

        attributes = transaction_attributes(response.parsed_body)

        expect(response).to have_http_status(:ok)
        expect(attributes).to include(
          "id" => transaction.id,
          "description" => "Grocery",
          "kind" => "expense",
          "status" => "pending",
          "payment_method" => "pix",
          "account_id" => account.id,
          "category_id" => category.id,
          "tag_ids" => [ tag.id ]
        )
        expect(attributes).not_to include(
          "credit_card_id",
          "limit_consumption_type",
          "source_account_id",
          "destination_account_id"
        )
        expect(attributes["recurrences"].size).to eq(1)
        expect(attributes["recurrences"].first).to include(
          "type" => "transaction_recurrence"
        )
      end

      it "returns 404 for another user's transaction" do
        show_transaction(create(:transaction).id)

        expect(response).to have_http_status(:not_found)
        expect(response.parsed_body["message"]).to eq("Transaction not found")
      end

      it "includes the current month's recurrence value" do
        travel_to(Date.new(2026, 8, 19)) do
          recurring = create(:transaction, :recurring, user:, account:, starts_on: Date.new(2026, 1, 31), value: 100)
          create(:transaction_recurrence, financial_transaction: recurring, starts_on: Date.new(2026, 8, 31), value: 107)
          create(:transaction_recurrence, financial_transaction: recurring, starts_on: Date.new(2026, 9, 30), value: 120)
          create(:transaction_recurrence, financial_transaction: recurring, starts_on: Date.new(2026, 10, 30), value: 110)

          show_transaction(recurring.id)

          expect(transaction_attributes(response.parsed_body)["current_value"]).to eq("107.0")
        end
      end
    end

    context "when unauthenticated" do
      subject { show_transaction(transaction.id, {}) }

      it_behaves_like "an unauthorized API request"
    end
  end

  describe "POST /api/v1/transactions" do
    def create_transaction(params, request_headers = headers)
      post "/api/v1/transactions", params: params, headers: request_headers, as: :json
    end

    context "when authenticated" do
      it "creates a one-time expense linked to an account" do
        expect {
          create_transaction(create_params)
        }.to change(Transaction::Record, :count).by(1)
          .and change(Transaction::ForAccount::Record, :count).by(1)
          .and change(Transaction::Recurrence::Record, :count).by(1)
          .and change(Transaction::Tagging::Record, :count).by(1)

        attributes = transaction_attributes(response.parsed_body)

        expect(response).to have_http_status(:created)
        expect(response.parsed_body["message"]).to eq("Transaction created successfully")
        expect(attributes).to include(
          "description" => "Grocery",
          "kind" => "expense",
          "status" => "pending",
          "payment_method" => "pix",
          "recurrence_type" => "one_time",
          "installments_count" => nil,
          "ends_on" => nil,
          "canceled_on" => nil,
          "account_id" => account.id
        )
        expect(attributes).not_to include(
          "credit_card_id",
          "limit_consumption_type",
          "source_account_id",
          "destination_account_id"
        )
        expect(attributes["recurrences"].first).to include("type" => "transaction_recurrence")
        expect(attributes["recurrences"].first["attributes"]).to include(
          "starts_on" => "2026-08-11",
          "value" => "100.0"
        )
      end

      it "ignores a client-provided status and persists pending" do
        create_transaction(create_params(status: "completed"))

        expect(response).to have_http_status(:created)
        expect(transaction_attributes(response.parsed_body)["status"]).to eq("pending")
      end

      it "creates an installment expense and calculates installments_count" do
        create_transaction(
          create_params(
            recurrence_type: "installment",
            starts_on: "2026-08-11",
            ends_on: "2026-09-11"
          )
        )

        attributes = transaction_attributes(response.parsed_body)

        expect(response).to have_http_status(:created)
        expect(attributes).to include(
          "recurrence_type" => "installment",
          "installments_count" => 2,
          "ends_on" => "2026-09-11"
        )
      end

      it "creates a credit card expense" do
        create_transaction(
          create_params(
            payment_method: "credit_card",
            account_id: nil,
            credit_card_id: credit_card.id
          ).tap { |params| params[:transaction].delete(:account_id) }
        )

        attributes = transaction_attributes(response.parsed_body)

        expect(response).to have_http_status(:created)
        expect(attributes).to include(
          "payment_method" => "credit_card",
          "credit_card_id" => credit_card.id,
          "limit_consumption_type" => "upfront"
        )
        expect(attributes).not_to include(
          "account_id",
          "source_account_id",
          "destination_account_id"
        )
        expect(Transaction::ForCreditCard::Record.count).to eq(1)
      end

      it "defaults limit_consumption_type to upfront for a one-time credit card expense" do
        create_transaction(
          create_params(
            payment_method: "credit_card",
            credit_card_id: credit_card.id
          ).tap { |params| params[:transaction].delete(:account_id) }
        )

        expect(response).to have_http_status(:created)
        expect(transaction_attributes(response.parsed_body)["limit_consumption_type"]).to eq("upfront")
      end

      it "forces limit_consumption_type to upfront when a one-time credit card expense sends monthly" do
        create_transaction(
          create_params(
            payment_method: "credit_card",
            credit_card_id: credit_card.id,
            limit_consumption_type: "monthly"
          ).tap { |params| params[:transaction].delete(:account_id) }
        )

        expect(response).to have_http_status(:created)
        expect(transaction_attributes(response.parsed_body)["limit_consumption_type"]).to eq("upfront")
      end

      it "creates a credit card installment with monthly limit consumption" do
        create_transaction(
          create_params(
            payment_method: "credit_card",
            recurrence_type: "installment",
            starts_on: "2026-08-11",
            ends_on: "2026-09-11",
            credit_card_id: credit_card.id,
            limit_consumption_type: "monthly"
          ).tap { |params| params[:transaction].delete(:account_id) }
        )

        expect(response).to have_http_status(:created)
        expect(transaction_attributes(response.parsed_body)).to include(
          "recurrence_type" => "installment",
          "limit_consumption_type" => "monthly"
        )
      end

      it "creates a credit card installment with upfront limit consumption" do
        create_transaction(
          create_params(
            payment_method: "credit_card",
            recurrence_type: "installment",
            starts_on: "2026-08-11",
            ends_on: "2026-09-11",
            credit_card_id: credit_card.id,
            limit_consumption_type: "upfront"
          ).tap { |params| params[:transaction].delete(:account_id) }
        )

        expect(response).to have_http_status(:created)
        expect(transaction_attributes(response.parsed_body)).to include(
          "recurrence_type" => "installment",
          "limit_consumption_type" => "upfront"
        )
      end

      it "rejects a credit card installment without limit_consumption_type" do
        create_transaction(
          create_params(
            payment_method: "credit_card",
            recurrence_type: "installment",
            starts_on: "2026-08-11",
            ends_on: "2026-09-11",
            credit_card_id: credit_card.id
          ).tap { |params| params[:transaction].delete(:account_id) }
        )

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "limit_consumption_type")).to be_present
      end

      it "defaults limit_consumption_type to monthly for a recurring credit card expense" do
        create_transaction(
          create_params(
            payment_method: "credit_card",
            recurrence_type: "recurring",
            credit_card_id: credit_card.id
          ).tap { |params| params[:transaction].delete(:account_id) }
        )

        expect(response).to have_http_status(:created)
        expect(transaction_attributes(response.parsed_body)["limit_consumption_type"]).to eq("monthly")
      end

      it "forces limit_consumption_type to monthly when a recurring credit card expense sends upfront" do
        create_transaction(
          create_params(
            payment_method: "credit_card",
            recurrence_type: "recurring",
            credit_card_id: credit_card.id,
            limit_consumption_type: "upfront"
          ).tap { |params| params[:transaction].delete(:account_id) }
        )

        expect(response).to have_http_status(:created)
        expect(transaction_attributes(response.parsed_body)["limit_consumption_type"]).to eq("monthly")
      end

      it "does not persist account_id when creating a credit card expense" do
        create_transaction(
          create_params(
            payment_method: "credit_card",
            credit_card_id: credit_card.id,
            account_id: account.id
          )
        )

        expect(response).to have_http_status(:created)
        expect(transaction_attributes(response.parsed_body)).not_to include("account_id")
        expect(Transaction::ForAccount::Record.count).to eq(0)
      end

      it "rejects a transaction without category_id" do
        create_transaction(create_params.tap { |params| params[:transaction].delete(:category_id) })

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "category_id")).to be_present
      end

      it "creates a transfer between accounts" do
        create_transaction(
          transaction: {
            description: "Move money",
            kind: "transfer_between_accounts",
            recurrence_type: "one_time",
            starts_on: "2026-08-11",
            value: 250,
            source_account_id: source_account.id,
            destination_account_id: destination_account.id,
            category_id: category.id
          }
        )

        attributes = transaction_attributes(response.parsed_body)

        expect(response).to have_http_status(:created)
        expect(attributes).to include(
          "kind" => "transfer_between_accounts",
          "payment_method" => nil,
          "source_account_id" => source_account.id,
          "destination_account_id" => destination_account.id
        )
        expect(attributes).not_to include(
          "account_id",
          "credit_card_id",
          "limit_consumption_type"
        )
      end

      it "rejects debit payment_method for income" do
        create_transaction(create_params(kind: "income", payment_method: "debit"))

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "payment_method")).to be_present
      end

      it "rejects payment_method for transfers" do
        create_transaction(
          transaction: {
            description: "Move money",
            kind: "transfer_between_accounts",
            payment_method: "pix",
            recurrence_type: "one_time",
            starts_on: "2026-08-11",
            value: 250,
            source_account_id: source_account.id,
            destination_account_id: destination_account.id,
            category_id: category.id
          }
        )

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "payment_method")).to be_present
      end

      it "rejects same source and destination accounts" do
        create_transaction(
          transaction: {
            description: "Move money",
            kind: "transfer_between_accounts",
            recurrence_type: "one_time",
            starts_on: "2026-08-11",
            value: 250,
            source_account_id: source_account.id,
            destination_account_id: source_account.id,
            category_id: category.id
          }
        )

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "destination_account_id")).to be_present
      end

      it "rejects another user's account" do
        create_transaction(create_params(account_id: create(:account).id))

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "account_id")).to be_present
      end

      it "rejects an inactive account" do
        create_transaction(create_params(account_id: create(:account, :inactive, user:).id))

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "account_id")).to eq([ "is inactive" ])
      end

      it "rejects an inactive category" do
        create_transaction(create_params(category_id: create(:category, :inactive, user:).id))

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "category_id")).to eq([ "is inactive" ])
      end

      it "rejects an inactive tag" do
        create_transaction(create_params(tag_ids: [ create(:tag, :inactive, user:).id ]))

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "tag_ids")).to eq([ "contains an inactive tag" ])
      end

      it "rejects an inactive credit card" do
        create_transaction(
          create_params(
            payment_method: "credit_card",
            credit_card_id: create(:credit_card, :inactive, user:).id,
            limit_consumption_type: "upfront"
          ).tap { |params| params[:transaction].delete(:account_id) }
        )

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "credit_card_id")).to eq([ "is inactive" ])
      end

      it "rejects another user's credit card" do
        create_transaction(
          create_params(
            payment_method: "credit_card",
            credit_card_id: create(:credit_card).id,
            limit_consumption_type: "upfront"
          ).tap { |params| params[:transaction].delete(:account_id) }
        )

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "credit_card_id")).to be_present
      end

      it "rejects installment without ends_on" do
        create_transaction(create_params(recurrence_type: "installment"))

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "ends_on")).to be_present
      end

      it "rejects one_time with ends_on" do
        create_transaction(create_params(ends_on: "2026-09-11"))

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "ends_on")).to be_present
      end

      it "creates a transaction in an open month" do
        create(:monthly_status, user:, month: 8, year: 2026)

        expect {
          create_transaction(create_params)
        }.to change(Transaction::Record, :count).by(1)

        expect(response).to have_http_status(:created)
      end

      it "creates a transaction in a month with no row and persists an open monthly status" do
        expect {
          create_transaction(create_params)
        }.to change(Transaction::Record, :count).by(1)
          .and change(MonthlyStatus::Record, :count).by(1)

        expect(response).to have_http_status(:created)
        expect(MonthlyStatus::Record.find_by!(user_id: user.id, month: 8, year: 2026).status).to eq("open")
      end

      it "rejects a transaction in a closed month" do
        create(:monthly_status, :closed, user:, month: 8, year: 2026)

        create_transaction(create_params)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "base")).to eq([
          "Transactions cannot be created for this date because the month is already closed"
        ])
        expect(Transaction::Record.count).to eq(0)
      end

      it "rejects a transaction in a missing month that precedes a closed month" do
        create(:monthly_status, :closed, user:, month: 9, year: 2026)

        expect {
          create_transaction(create_params)
        }.not_to change(MonthlyStatus::Record, :count)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "base")).to eq([
          "Transactions cannot be created for this date because a later month is already closed"
        ])
        expect(Transaction::Record.count).to eq(0)
        expect(MonthlyStatus::Record.find_by(user_id: user.id, month: 8, year: 2026)).to be_nil
      end

      it "rejects a closed-month transaction in Portuguese when the user locale is pt-BR" do
        user.update!(configs: { "locale" => "pt-BR" })
        create(:monthly_status, :closed, user:, month: 8, year: 2026)

        create_transaction(create_params)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "base")).to eq([
          "Não é possível criar transações nesta data, pois o mês já está fechado"
        ])
      end

      it "creates a credit card transaction when starts_on is in a closed civil month whose cycle is open" do
        card = create(:credit_card, user:, closing_day: 10, due_day: 17)
        create(:monthly_status, :closed, user:, month: 8, year: 2026)

        create_transaction(
          create_params(
            payment_method: "credit_card",
            starts_on: "2026-08-28",
            credit_card_id: card.id
          ).tap { |params| params[:transaction].delete(:account_id) }
        )

        expect(response).to have_http_status(:created)
        expect(MonthlyStatus::Record.find_by!(user_id: user.id, month: 9, year: 2026)).to have_attributes(status: "open")
      end

      it "rejects a credit card expense whose starts_on falls in a paid invoice" do
        card = create(:credit_card, user:, closing_day: 10, due_day: 17)
        create(
          :credit_card_invoice_settlement,
          credit_card: card,
          payment_account: card.default_payment_account,
          opening_date: Date.new(2026, 7, 11),
          closing_date: Date.new(2026, 8, 10),
          due_date: Date.new(2026, 8, 17)
        )

        create_transaction(
          create_params(
            payment_method: "credit_card",
            starts_on: "2026-08-01",
            credit_card_id: card.id
          ).tap { |params| params[:transaction].delete(:account_id) }
        )

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "base")).to eq([
          "Expenses cannot be posted to this card because the invoice for this period has already been paid"
        ])
        expect(Transaction::Record.count).to eq(0)
      end

      it "rejects a paid-invoice credit card expense in Portuguese when the user locale is pt-BR" do
        user.update!(configs: { "locale" => "pt-BR" })
        card = create(:credit_card, user:, closing_day: 10, due_day: 17)
        create(
          :credit_card_invoice_settlement,
          credit_card: card,
          payment_account: card.default_payment_account,
          opening_date: Date.new(2026, 7, 11),
          closing_date: Date.new(2026, 8, 10),
          due_date: Date.new(2026, 8, 17)
        )

        create_transaction(
          create_params(
            payment_method: "credit_card",
            starts_on: "2026-08-01",
            credit_card_id: card.id
          ).tap { |params| params[:transaction].delete(:account_id) }
        )

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "base")).to eq([
          "Não é possível lançar despesas neste cartão, pois a fatura deste período já foi paga"
        ])
      end

      it "creates a credit card expense when starts_on is after the paid invoice cycle" do
        card = create(:credit_card, user:, closing_day: 10, due_day: 17)
        create(
          :credit_card_invoice_settlement,
          credit_card: card,
          payment_account: card.default_payment_account,
          opening_date: Date.new(2026, 7, 11),
          closing_date: Date.new(2026, 8, 10),
          due_date: Date.new(2026, 8, 17)
        )

        create_transaction(
          create_params(
            payment_method: "credit_card",
            starts_on: "2026-08-11",
            credit_card_id: card.id
          ).tap { |params| params[:transaction].delete(:account_id) }
        )

        expect(response).to have_http_status(:created)
      end

      it "rejects an installment whose period overlaps a paid invoice" do
        card = create(:credit_card, user:, closing_day: 10, due_day: 17)
        create(
          :credit_card_invoice_settlement,
          credit_card: card,
          payment_account: card.default_payment_account,
          opening_date: Date.new(2026, 7, 11),
          closing_date: Date.new(2026, 8, 10),
          due_date: Date.new(2026, 8, 17)
        )

        create_transaction(
          create_params(
            payment_method: "credit_card",
            recurrence_type: "installment",
            starts_on: "2026-07-05",
            ends_on: "2026-09-05",
            credit_card_id: card.id
          ).tap { |params| params[:transaction].delete(:account_id) }
        )

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "base")).to eq([
          "Expenses cannot be posted to this card because the invoice for this period has already been paid"
        ])
        expect(Transaction::Record.count).to eq(0)
      end
    end

    context "when unauthenticated" do
      subject { create_transaction(create_params, {}) }

      it_behaves_like "an unauthorized API request"
    end
  end

  describe "PATCH /api/v1/transactions/:id" do
    let(:transaction) { create(:transaction, :recurring, user:, account:, category:, description: "Rent", value: 100) }

    def update_transaction(id, params, request_headers = headers)
      patch "/api/v1/transactions/#{id}", params: params, headers: request_headers, as: :json
    end

    context "when authenticated" do
      it "updates the description" do
        update_transaction(transaction.id, transaction: { description: "Updated rent" })

        expect(response).to have_http_status(:ok)
        expect(transaction_attributes(response.parsed_body)["description"]).to eq("Updated rent")
        expect(transaction_attributes(response.parsed_body)["status"]).to eq("pending")
      end

      it "does not change status" do
        update_transaction(transaction.id, transaction: { status: "canceled", description: "Updated rent" })

        expect(response).to have_http_status(:ok)
        expect(transaction_attributes(response.parsed_body)["description"]).to eq("Updated rent")
        expect(transaction_attributes(response.parsed_body)["status"]).to eq("pending")
      end

      it "updates the existing recurrence when starts_on and value change" do
        transaction

        expect {
          update_transaction(
            transaction.id,
            transaction: { starts_on: "2026-10-11", value: 120 }
          )
        }.not_to change(Transaction::Recurrence::Record, :count)

        recurrences = transaction_recurrences(response.parsed_body)

        expect(response).to have_http_status(:ok)
        expect(recurrences.map { |item| [ item["starts_on"], item["value"] ] }).to eq(
          [ [ "2026-10-11", "120.0" ] ]
        )
      end

      it "allows changing a pending transaction to a transfer and clears exclusive fields" do
        update_transaction(
          transaction.id,
          transaction: {
            kind: "transfer_between_accounts",
            source_account_id: source_account.id,
            destination_account_id: destination_account.id
          }
        )

        attributes = transaction_attributes(response.parsed_body)

        expect(response).to have_http_status(:ok)
        expect(attributes).to include(
          "kind" => "transfer_between_accounts",
          "payment_method" => nil,
          "source_account_id" => source_account.id,
          "destination_account_id" => destination_account.id
        )
        expect(attributes).not_to include("account_id", "credit_card_id", "limit_consumption_type")
        expect(Transaction::ForAccount::Record.where(transaction_id: transaction.id)).to be_empty
      end

      it "allows changing a pending payment method to credit card and clears the account" do
        pending_expense = create(:transaction, user:, account:, category:)

        update_transaction(
          pending_expense.id,
          transaction: {
            payment_method: "credit_card",
            credit_card_id: credit_card.id
          }
        )

        attributes = transaction_attributes(response.parsed_body)

        expect(response).to have_http_status(:ok)
        expect(attributes).to include(
          "payment_method" => "credit_card",
          "credit_card_id" => credit_card.id,
          "limit_consumption_type" => "upfront"
        )
        expect(attributes).not_to include("account_id")
        expect(Transaction::ForAccount::Record.where(transaction_id: pending_expense.id)).to be_empty
      end

      it "clears ends_on when a pending installment becomes one_time" do
        installment = create(:transaction, :installment, user:, account:, category:)

        update_transaction(installment.id, transaction: { recurrence_type: "one_time" })

        attributes = transaction_attributes(response.parsed_body)

        expect(response).to have_http_status(:ok)
        expect(attributes).to include(
          "recurrence_type" => "one_time",
          "ends_on" => nil,
          "installments_count" => nil
        )
      end

      it "defaults limit_consumption_type to upfront when a pending credit card installment becomes one_time" do
        installment = create(
          :transaction,
          :installment,
          :with_credit_card,
          user:,
          credit_card:,
          category:,
          limit_consumption_type: "monthly"
        )

        update_transaction(installment.id, transaction: { recurrence_type: "one_time" })

        expect(response).to have_http_status(:ok)
        expect(transaction_attributes(response.parsed_body)).to include(
          "recurrence_type" => "one_time",
          "limit_consumption_type" => "upfront"
        )
      end

      it "allows changing a pending kind to income" do
        update_transaction(transaction.id, transaction: { kind: "income", payment_method: "pix" })

        expect(response).to have_http_status(:ok)
        expect(transaction_attributes(response.parsed_body)).to include(
          "kind" => "income",
          "payment_method" => "pix"
        )
      end

      it "allows changing a pending recurrence to installment and calculates installments_count" do
        update_transaction(
          transaction.id,
          transaction: { recurrence_type: "installment", ends_on: "2026-10-11" }
        )

        expect(response).to have_http_status(:ok)
        expect(transaction_attributes(response.parsed_body)).to include(
          "recurrence_type" => "installment",
          "installments_count" => 3,
          "ends_on" => "2026-10-11"
        )
      end

      it "defaults limit_consumption_type to monthly when a pending recurring expense becomes credit card" do
        update_transaction(
          transaction.id,
          transaction: { payment_method: "credit_card", credit_card_id: credit_card.id }
        )

        expect(response).to have_http_status(:ok)
        expect(transaction_attributes(response.parsed_body)).to include(
          "payment_method" => "credit_card",
          "credit_card_id" => credit_card.id,
          "limit_consumption_type" => "monthly"
        )
      end

      it "forces limit_consumption_type to monthly when a pending credit card installment becomes recurring" do
        installment = create(
          :transaction,
          :installment,
          :with_credit_card,
          user:,
          credit_card:,
          category:,
          limit_consumption_type: "upfront"
        )

        update_transaction(installment.id, transaction: { recurrence_type: "recurring" })

        expect(response).to have_http_status(:ok)
        expect(transaction_attributes(response.parsed_body)).to include(
          "recurrence_type" => "recurring",
          "limit_consumption_type" => "monthly"
        )
      end

      it "keeps the chosen limit_consumption_type when updating a pending credit card installment" do
        installment = create(
          :transaction,
          :installment,
          :with_credit_card,
          user:,
          credit_card:,
          category:,
          limit_consumption_type: "monthly"
        )

        update_transaction(installment.id, transaction: { description: "Updated installment" })

        expect(response).to have_http_status(:ok)
        expect(transaction_attributes(response.parsed_body)).to include(
          "description" => "Updated installment",
          "limit_consumption_type" => "monthly"
        )
      end

      it "allows changing a pending credit card back to an account payment and clears the card" do
        card_transaction = create(:transaction, :with_credit_card, user:, credit_card:, category:)

        update_transaction(
          card_transaction.id,
          transaction: { payment_method: "pix", account_id: account.id }
        )

        attributes = transaction_attributes(response.parsed_body)

        expect(response).to have_http_status(:ok)
        expect(attributes).to include("payment_method" => "pix", "account_id" => account.id)
        expect(attributes).not_to include("credit_card_id", "limit_consumption_type")
        expect(Transaction::ForCreditCard::Record.where(transaction_id: card_transaction.id)).to be_empty
      end

      it "allows changing a pending transfer back to an expense and clears transfer accounts" do
        transfer = create(:transaction, :transfer, user:, source_account:, destination_account:, category:)

        update_transaction(
          transfer.id,
          transaction: { kind: "expense", payment_method: "pix", account_id: account.id }
        )

        attributes = transaction_attributes(response.parsed_body)

        expect(response).to have_http_status(:ok)
        expect(attributes).to include("kind" => "expense", "account_id" => account.id)
        expect(attributes).not_to include("source_account_id", "destination_account_id")
        expect(Transaction::ForTransferBetweenAccounts::Record.where(transaction_id: transfer.id)).to be_empty
      end

      it "rejects debit payment_method when changing a pending kind to income" do
        update_transaction(transaction.id, transaction: { kind: "income", payment_method: "debit" })

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "payment_method")).to be_present
      end

      it "rejects same source and destination accounts on a pending transfer update" do
        update_transaction(
          transaction.id,
          transaction: {
            kind: "transfer_between_accounts",
            source_account_id: source_account.id,
            destination_account_id: source_account.id
          }
        )

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "destination_account_id")).to be_present
      end

      it "keeps an already linked inactive category" do
        category.update!(active: false)

        update_transaction(transaction.id, transaction: { category_id: category.id, description: "Still valid" })

        expect(response).to have_http_status(:ok)
        expect(transaction_attributes(response.parsed_body)).to include(
          "category_id" => category.id,
          "description" => "Still valid"
        )
      end

      it "rejects a newly selected inactive category" do
        inactive_category = create(:category, :inactive, user:)

        update_transaction(transaction.id, transaction: { category_id: inactive_category.id })

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "category_id")).to eq([ "is inactive" ])
      end

      it "keeps an already linked inactive account" do
        account.update!(active: false)

        update_transaction(transaction.id, transaction: { account_id: account.id, description: "Still valid" })

        expect(response).to have_http_status(:ok)
        expect(transaction_attributes(response.parsed_body)["account_id"]).to eq(account.id)
      end

      it "rejects a newly selected inactive account" do
        inactive_account = create(:account, :inactive, user:)

        update_transaction(transaction.id, transaction: { account_id: inactive_account.id })

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "account_id")).to eq([ "is inactive" ])
      end

      it "keeps an already linked inactive credit card" do
        card_transaction = create(:transaction, :with_credit_card, user:, credit_card:, category:)
        credit_card.update!(active: false)

        update_transaction(
          card_transaction.id,
          transaction: { credit_card_id: credit_card.id, description: "Still valid" }
        )

        expect(response).to have_http_status(:ok)
        expect(transaction_attributes(response.parsed_body)["credit_card_id"]).to eq(credit_card.id)
      end

      it "rejects a newly selected inactive credit card" do
        card_transaction = create(:transaction, :with_credit_card, user:, credit_card:, category:)
        inactive_card = create(:credit_card, :inactive, user:)

        update_transaction(card_transaction.id, transaction: { credit_card_id: inactive_card.id })

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "credit_card_id")).to eq([ "is inactive" ])
      end

      it "rejects moving a pending credit card expense onto a paid invoice" do
        card = create(:credit_card, user:, closing_day: 10, due_day: 17)
        card_transaction = create(
          :transaction,
          :with_credit_card,
          user:,
          credit_card: card,
          category:,
          starts_on: Date.new(2026, 8, 11)
        )
        create(
          :credit_card_invoice_settlement,
          credit_card: card,
          payment_account: card.default_payment_account,
          opening_date: Date.new(2026, 7, 11),
          closing_date: Date.new(2026, 8, 10),
          due_date: Date.new(2026, 8, 17)
        )

        update_transaction(card_transaction.id, transaction: { starts_on: "2026-08-01" })

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "base")).to eq([
          "Expenses cannot be posted to this card because the invoice for this period has already been paid"
        ])
      end

      it "rejects changing a pending expense to a credit card whose invoice is already paid" do
        card = create(:credit_card, user:, closing_day: 10, due_day: 17)
        create(
          :credit_card_invoice_settlement,
          credit_card: card,
          payment_account: card.default_payment_account,
          opening_date: Date.new(2026, 7, 11),
          closing_date: Date.new(2026, 8, 10),
          due_date: Date.new(2026, 8, 17)
        )
        expense = create(:transaction, user:, account:, category:, starts_on: Date.new(2026, 8, 1))

        update_transaction(
          expense.id,
          transaction: { payment_method: "credit_card", credit_card_id: card.id }
        )

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "base")).to eq([
          "Expenses cannot be posted to this card because the invoice for this period has already been paid"
        ])
      end

      it "keeps an already linked inactive tag" do
        tagged = create(:transaction, user:, account:, category:, tags: [ tag ])
        tag.update!(active: false)

        update_transaction(tagged.id, transaction: { tag_ids: [ tag.id ], description: "Still valid" })

        expect(response).to have_http_status(:ok)
        expect(transaction_attributes(response.parsed_body)["tag_ids"]).to eq([ tag.id ])
      end

      it "rejects a newly selected inactive tag" do
        inactive_tag = create(:tag, :inactive, user:)

        update_transaction(transaction.id, transaction: { tag_ids: [ inactive_tag.id ] })

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "tag_ids")).to eq([ "contains an inactive tag" ])
      end

      it "keeps already linked inactive transfer accounts" do
        transfer = create(:transaction, :transfer, user:, source_account:, destination_account:, category:)
        source_account.update!(active: false)

        update_transaction(
          transfer.id,
          transaction: { source_account_id: source_account.id, description: "Still valid" }
        )

        expect(response).to have_http_status(:ok)
        expect(transaction_attributes(response.parsed_body)["source_account_id"]).to eq(source_account.id)
      end

      it "rejects a newly selected inactive source account" do
        transfer = create(:transaction, :transfer, user:, source_account:, destination_account:, category:)
        inactive_account = create(:account, :inactive, user:)

        update_transaction(transfer.id, transaction: { source_account_id: inactive_account.id })

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "source_account_id")).to eq([ "is inactive" ])
      end

      context "when the transaction is active" do
        let(:transaction) { create(:transaction, :recurring, :active, user:, account:, category:, description: "Rent") }

        it "allows changing the account" do
          other_account = create(:account, user:, name: "Other")

          update_transaction(transaction.id, transaction: { account_id: other_account.id })

          expect(response).to have_http_status(:ok)
          expect(transaction_attributes(response.parsed_body)["account_id"]).to eq(other_account.id)
        end

        it "allows changing the credit card" do
          card_transaction = create(:transaction, :with_credit_card, :active, user:, credit_card:, category:)
          other_card = create(:credit_card, user:, name: "Other Card")

          update_transaction(card_transaction.id, transaction: { credit_card_id: other_card.id })

          expect(response).to have_http_status(:ok)
          expect(transaction_attributes(response.parsed_body)["credit_card_id"]).to eq(other_card.id)
        end

        it "rejects changing the credit card when the target card invoice covering starts_on is paid" do
          card_transaction = create(
            :transaction,
            :with_credit_card,
            :active,
            user:,
            credit_card:,
            category:,
            starts_on: Date.new(2026, 8, 1)
          )
          other_card = create(:credit_card, user:, name: "Other Card", closing_day: 10, due_day: 17)
          create(
            :credit_card_invoice_settlement,
            credit_card: other_card,
            payment_account: other_card.default_payment_account,
            opening_date: Date.new(2026, 7, 11),
            closing_date: Date.new(2026, 8, 10),
            due_date: Date.new(2026, 8, 17)
          )

          update_transaction(card_transaction.id, transaction: { credit_card_id: other_card.id })

          expect(response).to have_http_status(:unprocessable_content)
          expect(response.parsed_body.dig("details", "base")).to eq([
            "Expenses cannot be posted to this card because the invoice for this period has already been paid"
          ])
        end

        it "allows changing source and destination accounts" do
          transfer = create(:transaction, :transfer, :active, user:, source_account:, destination_account:, category:)
          other_source = create(:account, user:, name: "New Source")
          other_destination = create(:account, user:, name: "New Destination")

          update_transaction(
            transfer.id,
            transaction: { source_account_id: other_source.id, destination_account_id: other_destination.id }
          )

          expect(response).to have_http_status(:ok)
          expect(transaction_attributes(response.parsed_body)).to include(
            "source_account_id" => other_source.id,
            "destination_account_id" => other_destination.id
          )
        end

        it "allows changing ends_on for a recurring transaction" do
          update_transaction(transaction.id, transaction: { ends_on: "2026-12-11" })

          expect(response).to have_http_status(:ok)
          expect(transaction_attributes(response.parsed_body)["ends_on"]).to eq("2026-12-11")
        end

        it "allows ends_on on the latest existing recurrence starts_on" do
          create(:transaction_recurrence, financial_transaction: transaction, starts_on: Date.new(2026, 10, 11), value: 150)

          update_transaction(transaction.id, transaction: { ends_on: "2026-10-11" })

          expect(response).to have_http_status(:ok)
          expect(transaction_attributes(response.parsed_body)["ends_on"]).to eq("2026-10-11")
        end

        it "rejects ends_on before an existing later recurrence" do
          create(:transaction_recurrence, financial_transaction: transaction, starts_on: Date.new(2026, 10, 11), value: 150)

          update_transaction(transaction.id, transaction: { ends_on: "2026-09-11" })

          expect(response).to have_http_status(:unprocessable_content)
          expect(response.parsed_body.dig("details", "ends_on")).to eq([ "cannot be before an existing value change" ])
        end

        it "rejects kind, payment_method, recurrence_type, value, starts_on and limit_consumption_type" do
          update_transaction(
            transaction.id,
            transaction: {
              kind: "income",
              payment_method: "ted",
              recurrence_type: "one_time",
              value: 200,
              starts_on: "2026-10-11",
              limit_consumption_type: "monthly"
            }
          )

          expect(response).to have_http_status(:unprocessable_content)
          expect(response.parsed_body["details"]).to include(
            "kind",
            "payment_method",
            "recurrence_type",
            "value",
            "starts_on",
            "limit_consumption_type"
          )
        end

        it "rejects ends_on for an installment transaction" do
          installment = create(:transaction, :installment, :active, user:, account:, category:)

          update_transaction(installment.id, transaction: { ends_on: "2026-12-11" })

          expect(response).to have_http_status(:unprocessable_content)
          expect(response.parsed_body.dig("details", "ends_on")).to be_present
        end
      end

      context "when the transaction is completed" do
        let(:transaction) { create(:transaction, :completed, user:, account:, category:, description: "Rent") }

        it "allows changing description, category and tags" do
          other_category = create(:category, user:, name: "Updated")

          update_transaction(
            transaction.id,
            transaction: { description: "Done", category_id: other_category.id, tag_ids: [ tag.id ] }
          )

          attributes = transaction_attributes(response.parsed_body)

          expect(response).to have_http_status(:ok)
          expect(attributes).to include(
            "description" => "Done",
            "category_id" => other_category.id,
            "tag_ids" => [ tag.id ]
          )
        end

        it "rejects schedule and payment target fields" do
          update_transaction(
            transaction.id,
            transaction: {
              kind: "income",
              payment_method: "ted",
              recurrence_type: "one_time",
              starts_on: "2026-10-11",
              ends_on: "2026-12-11",
              value: 200,
              limit_consumption_type: "monthly",
              account_id: create(:account, user:).id,
              credit_card_id: credit_card.id,
              source_account_id: source_account.id,
              destination_account_id: destination_account.id
            }
          )

          expect(response).to have_http_status(:unprocessable_content)
          expect(response.parsed_body["details"]).to include(
            "kind",
            "payment_method",
            "recurrence_type",
            "starts_on",
            "ends_on",
            "value",
            "limit_consumption_type",
            "account_id",
            "credit_card_id",
            "source_account_id",
            "destination_account_id"
          )
        end
      end

      context "when the transaction is canceled" do
        let(:transaction) { create(:transaction, :canceled, user:, account:, category:, description: "Rent") }

        it "allows changing description, category and tags" do
          other_category = create(:category, user:, name: "Updated")

          update_transaction(
            transaction.id,
            transaction: { description: "Canceled note", category_id: other_category.id, tag_ids: [ tag.id ] }
          )

          attributes = transaction_attributes(response.parsed_body)

          expect(response).to have_http_status(:ok)
          expect(attributes).to include(
            "description" => "Canceled note",
            "category_id" => other_category.id,
            "tag_ids" => [ tag.id ]
          )
        end

        it "rejects schedule and payment target fields" do
          update_transaction(
            transaction.id,
            transaction: { account_id: create(:account, user:).id, value: 200, kind: "income" }
          )

          expect(response).to have_http_status(:unprocessable_content)
          expect(response.parsed_body["details"]).to include("account_id", "value", "kind")
        end
      end

      it "returns 404 for another user's transaction" do
        update_transaction(create(:transaction).id, transaction: { description: "Hack" })

        expect(response).to have_http_status(:not_found)
      end
    end

    context "when unauthenticated" do
      subject { update_transaction(transaction.id, { transaction: { description: "Hack" } }, {}) }

      it_behaves_like "an unauthorized API request"
    end
  end

  describe "DELETE /api/v1/transactions/:id" do
    let!(:transaction) { create(:transaction, user:, account:) }

    def destroy_transaction(id, request_headers = headers)
      delete "/api/v1/transactions/#{id}", headers: request_headers, as: :json
    end

    context "when authenticated" do
      context "when the transaction is pending" do
        it "deletes the transaction and dependents" do
          expect {
            destroy_transaction(transaction.id)
          }.to change(Transaction::Record, :count).by(-1)
            .and change(Transaction::ForAccount::Record, :count).by(-1)
            .and change(Transaction::Recurrence::Record, :count).by(-1)

          expect(response).to have_http_status(:ok)
          expect(response.parsed_body["message"]).to eq("Transaction deleted successfully")
        end
      end

      context "when the transaction is active" do
        let!(:transaction) { create(:transaction, :active, user:, account:) }

        it "does not allow deletion" do
          expect { destroy_transaction(transaction.id) }.not_to change(Transaction::Record, :count)

          expect(response).to have_http_status(:unprocessable_content)
          expect(response.parsed_body.dig("details", "base")).to eq(
            [ "Transaction cannot be deleted in the current status" ]
          )
          expect(transaction.reload.status).to eq("active")
        end
      end

      context "when the transaction is completed" do
        let!(:transaction) { create(:transaction, :completed, user:, account:) }

        it "does not allow deletion" do
          expect { destroy_transaction(transaction.id) }.not_to change(Transaction::Record, :count)

          expect(response).to have_http_status(:unprocessable_content)
          expect(response.parsed_body.dig("details", "base")).to eq(
            [ "Transaction cannot be deleted in the current status" ]
          )
          expect(transaction.reload.status).to eq("completed")
        end
      end

      context "when the transaction is canceled" do
        let!(:transaction) { create(:transaction, :canceled, user:, account:) }

        it "does not allow deletion" do
          expect { destroy_transaction(transaction.id) }.not_to change(Transaction::Record, :count)

          expect(response).to have_http_status(:unprocessable_content)
          expect(response.parsed_body.dig("details", "base")).to eq(
            [ "Transaction cannot be deleted in the current status" ]
          )
          expect(transaction.reload.status).to eq("canceled")
        end
      end

      it "returns 404 for another user's transaction" do
        destroy_transaction(create(:transaction).id)

        expect(response).to have_http_status(:not_found)
      end
    end

    context "when unauthenticated" do
      subject { destroy_transaction(transaction.id, {}) }

      it_behaves_like "an unauthorized API request"
    end
  end

  describe "POST /api/v1/transactions/:id/cancel" do
    let!(:transaction) { create(:transaction, :active, user:, account:) }

    def cancel_transaction(id, request_headers = headers)
      post "/api/v1/transactions/#{id}/cancel", headers: request_headers, as: :json
    end

    context "when authenticated" do
      context "when the transaction is active" do
        it "cancels the transaction" do
          travel_to(Date.new(2026, 8, 21)) do
            expect {
              cancel_transaction(transaction.id)
            }.to change(Transaction::Record, :count).by(0)
              .and change(Transaction::ForAccount::Record, :count).by(0)
              .and change(Transaction::Recurrence::Record, :count).by(0)

            expect(response).to have_http_status(:ok)
            expect(response.parsed_body["message"]).to eq("Transaction canceled successfully")
            expect(transaction_attributes(response.parsed_body)).to include(
              "status" => "canceled",
              "canceled_on" => "2026-08-21"
            )
            expect(transaction.reload).to have_attributes(
              status: "canceled",
              canceled_on: Date.new(2026, 8, 21)
            )
          end
        end
      end

      context "when the transaction is pending" do
        let!(:transaction) { create(:transaction, user:, account:) }

        it "does not allow cancellation" do
          cancel_transaction(transaction.id)

          expect(response).to have_http_status(:unprocessable_content)
          expect(response.parsed_body.dig("details", "base")).to eq(
            [ "Transaction cannot be canceled in the current status" ]
          )
          expect(transaction.reload.status).to eq("pending")
        end
      end

      context "when the transaction is completed" do
        let!(:transaction) { create(:transaction, :completed, user:, account:) }

        it "does not allow cancellation" do
          cancel_transaction(transaction.id)

          expect(response).to have_http_status(:unprocessable_content)
          expect(response.parsed_body.dig("details", "base")).to eq(
            [ "Transaction cannot be canceled in the current status" ]
          )
          expect(transaction.reload.status).to eq("completed")
        end
      end

      context "when the transaction is canceled" do
        let!(:transaction) { create(:transaction, :canceled, user:, account:) }

        it "does not allow cancellation" do
          cancel_transaction(transaction.id)

          expect(response).to have_http_status(:unprocessable_content)
          expect(response.parsed_body.dig("details", "base")).to eq(
            [ "Transaction cannot be canceled in the current status" ]
          )
          expect(transaction.reload.status).to eq("canceled")
        end
      end

      it "returns 404 for another user's transaction" do
        cancel_transaction(create(:transaction, :active).id)

        expect(response).to have_http_status(:not_found)
      end
    end

    context "when unauthenticated" do
      subject { cancel_transaction(transaction.id, {}) }

      it_behaves_like "an unauthorized API request"
    end
  end
end
