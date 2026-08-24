require "rails_helper"

RSpec.describe "API::V1::MonthlyStatements", type: :request do
  let(:user) { create(:user, :verified) }
  let(:headers) { auth_headers_for(user) }
  let(:account) { create(:account, user:, name: "Checking") }
  let(:credit_card) { create(:credit_card, user:, name: "Nubank", closing_day: 10, due_day: 17) }

  def list_monthly_statements(query = {}, request_headers = headers)
    get "/api/v1/monthly_statements", params: query, headers: request_headers
  end

  def item_attributes(payload = response.parsed_body)
    payload.fetch("data").map { |item| item.fetch("attributes") }
  end

  def descriptions
    item_attributes.map { |item| item.fetch("description") }
  end

  def create_card_purchase(card, description, starts_on, *traits)
    create(:transaction, :with_credit_card, *traits, user:, credit_card: card, description:, starts_on:)
  end

  describe "GET /api/v1/monthly_statements" do
    context "when authenticated" do
      it "returns account and credit card transactions for the given period" do
        account_transaction = create(
          :transaction,
          user:,
          account:,
          description: "Rent",
          starts_on: Date.new(2026, 8, 11),
          value: 100
        )
        credit_card_transaction = create(
          :transaction,
          :with_credit_card,
          user:,
          credit_card:,
          description: "Grocery",
          starts_on: Date.new(2026, 8, 1),
          value: 250
        )

        list_monthly_statements(month: 8, year: 2026)

        by_id = item_attributes.index_by { |item| item.fetch("id") }

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["type"]).to eq("collection")
        expect(by_id.keys).to contain_exactly(account_transaction.id, credit_card_transaction.id)
        expect(by_id.fetch(account_transaction.id)).to include(
          "kind" => "expense",
          "description" => "Rent",
          "recurrence_type" => "one_time",
          "payment_method" => "account",
          "resource_id" => account.id,
          "resource_name" => "Checking",
          "resource_brand" => "#3B82F6",
          "opening_date" => "2026-08-01",
          "closing_date" => "2026-08-31",
          "due_date" => nil,
          "value" => "100.0",
          "first_recurrence_on" => "2026-08-11",
          "current_recurrence_on" => "2026-08-11",
          "starts_on" => "2026-08-11",
          "ends_on" => nil,
          "canceled_on" => nil
        )
        expect(by_id.fetch(credit_card_transaction.id)).to include(
          "kind" => "expense",
          "description" => "Grocery",
          "recurrence_type" => "one_time",
          "payment_method" => "credit_card",
          "resource_id" => credit_card.id,
          "resource_name" => "Nubank",
          "resource_brand" => "mastercard",
          "opening_date" => "2026-07-11",
          "closing_date" => "2026-08-10",
          "due_date" => "2026-08-17",
          "value" => "250.0",
          "first_recurrence_on" => "2026-08-01",
          "current_recurrence_on" => "2026-08-01",
          "starts_on" => "2026-08-01",
          "ends_on" => nil,
          "canceled_on" => nil
        )
      end

      it "groups account-based payment methods as account" do
        create(:transaction, user:, account:, payment_method: "debit", description: "Debit", starts_on: Date.new(2026, 8, 11))

        list_monthly_statements(month: 8, year: 2026)

        expect(item_attributes.first).to include("description" => "Debit", "payment_method" => "account")
      end

      it "uses the institution logo as resource_brand for bank accounts" do
        bank_account = create(:account, :bank_account, user:, name: "Bradesco")
        create(:transaction, user:, account: bank_account, description: "Salary", starts_on: Date.new(2026, 8, 11))

        list_monthly_statements(month: 8, year: 2026)

        expect(item_attributes.first).to include(
          "resource_id" => bank_account.id,
          "resource_name" => "Bradesco",
          "resource_brand" => bank_account.institution.logo_key
        )
      end

      it "includes income transactions" do
        create(:transaction, :income, user:, account:, description: "Salary", starts_on: Date.new(2026, 8, 11))

        list_monthly_statements(month: 8, year: 2026)

        expect(item_attributes.first).to include("kind" => "income", "description" => "Salary")
      end

      it "includes transactions on inactive accounts and credit cards" do
        inactive_account = create(:account, :inactive, user:, name: "Old wallet")
        inactive_card = create(:credit_card, :inactive, user:, name: "Old card", closing_day: 10, due_day: 17)
        create(:transaction, user:, account: inactive_account, description: "Cash", starts_on: Date.new(2026, 8, 11))
        create(
          :transaction,
          :with_credit_card,
          user:,
          credit_card: inactive_card,
          description: "Card",
          starts_on: Date.new(2026, 8, 1)
        )

        list_monthly_statements(month: 8, year: 2026)

        expect(descriptions).to contain_exactly("Cash", "Card")
      end

      it "does not return another user's transactions" do
        create(:transaction, user:, account:, description: "Mine", starts_on: Date.new(2026, 8, 11))
        create(:transaction, description: "Other", starts_on: Date.new(2026, 8, 11))
        create(:transaction, :with_credit_card, description: "Other card", starts_on: Date.new(2026, 8, 1))

        list_monthly_statements(month: 8, year: 2026)

        expect(response).to have_http_status(:ok)
        expect(descriptions).to eq(%w[Mine])
      end

      it "does not return transfers between accounts" do
        create(:transaction, :transfer, user:, description: "Transfer", starts_on: Date.new(2026, 8, 11))
        create(:transaction, user:, account:, description: "Rent", starts_on: Date.new(2026, 8, 11))

        list_monthly_statements(month: 8, year: 2026)

        expect(descriptions).to eq(%w[Rent])
      end

      it "excludes transactions that have no recurrences" do
        transaction = create(:transaction, user:, account:, with_links: false, description: "Orphan")
        Transaction::ForAccount::Record.create!(financial_transaction: transaction, account:)
        create(:transaction, user:, account:, description: "Current", starts_on: Date.new(2026, 8, 11))

        list_monthly_statements(month: 8, year: 2026)

        expect(descriptions).to eq(%w[Current])
      end

      context "account calendar period" do
        it "includes one-time transactions on the first and last day of the month" do
          create(:transaction, user:, account:, description: "First day", starts_on: Date.new(2026, 8, 1))
          create(:transaction, user:, account:, description: "Last day", starts_on: Date.new(2026, 8, 31))

          list_monthly_statements(month: 8, year: 2026)

          expect(descriptions).to contain_exactly("First day", "Last day")
          expect(item_attributes).to all(include("opening_date" => "2026-08-01", "closing_date" => "2026-08-31"))
        end

        it "excludes one-time transactions from the previous and next months" do
          create(:transaction, user:, account:, description: "July", starts_on: Date.new(2026, 7, 31))
          create(:transaction, user:, account:, description: "August", starts_on: Date.new(2026, 8, 15))
          create(:transaction, user:, account:, description: "September", starts_on: Date.new(2026, 9, 1))

          list_monthly_statements(month: 8, year: 2026)

          expect(descriptions).to eq(%w[August])
        end

        it "clamps the account closing date to the last day of February" do
          create(:transaction, user:, account:, description: "Feb 28", starts_on: Date.new(2026, 2, 28))
          create(:transaction, user:, account:, description: "Mar 1", starts_on: Date.new(2026, 3, 1))

          list_monthly_statements(month: 2, year: 2026)

          expect(descriptions).to eq([ "Feb 28" ])
          expect(item_attributes.first).to include("opening_date" => "2026-02-01", "closing_date" => "2026-02-28")
        end

        it "includes February 29 on a leap year" do
          create(:transaction, user:, account:, description: "Leap day", starts_on: Date.new(2028, 2, 29))
          create(:transaction, user:, account:, description: "Mar 1", starts_on: Date.new(2028, 3, 1))

          list_monthly_statements(month: 2, year: 2028)

          expect(descriptions).to eq([ "Leap day" ])
          expect(item_attributes.first).to include("opening_date" => "2028-02-01", "closing_date" => "2028-02-29")
        end
      end

      context "credit card billing cycle" do
        it "includes one-time transactions on the cycle opening and closing dates" do
          create(
            :transaction,
            :with_credit_card,
            user:,
            credit_card:,
            description: "Opening",
            starts_on: Date.new(2026, 7, 11)
          )
          create(
            :transaction,
            :with_credit_card,
            user:,
            credit_card:,
            description: "Closing",
            starts_on: Date.new(2026, 8, 10)
          )

          list_monthly_statements(month: 8, year: 2026)

          expect(descriptions).to contain_exactly("Opening", "Closing")
          expect(item_attributes).to all(
            include("opening_date" => "2026-07-11", "closing_date" => "2026-08-10", "due_date" => "2026-08-17")
          )
        end

        it "excludes one-time transactions before the cycle opening date" do
          create(
            :transaction,
            :with_credit_card,
            user:,
            credit_card:,
            description: "Previous cycle",
            starts_on: Date.new(2026, 7, 10)
          )
          create(
            :transaction,
            :with_credit_card,
            user:,
            credit_card:,
            description: "This cycle",
            starts_on: Date.new(2026, 7, 11)
          )

          list_monthly_statements(month: 8, year: 2026)

          expect(descriptions).to eq([ "This cycle" ])
        end

        it "excludes credit card transactions whose current recurrence starts after the billing cycle closing date" do
          create(
            :transaction,
            :with_credit_card,
            user:,
            credit_card:,
            description: "Next cycle",
            starts_on: Date.new(2026, 8, 11)
          )
          create(
            :transaction,
            :with_credit_card,
            user:,
            credit_card:,
            description: "This cycle",
            starts_on: Date.new(2026, 8, 10)
          )

          list_monthly_statements(month: 8, year: 2026)

          expect(descriptions).to eq([ "This cycle" ])
        end

        it "places closing in the previous month when closing_day is after due_day" do
          card = create(:credit_card, user:, name: "Late close", closing_day: 25, due_day: 10)
          create(
            :transaction,
            :with_credit_card,
            user:,
            credit_card: card,
            description: "Opening",
            starts_on: Date.new(2026, 6, 26)
          )
          create(
            :transaction,
            :with_credit_card,
            user:,
            credit_card: card,
            description: "Before opening",
            starts_on: Date.new(2026, 6, 25)
          )
          create(
            :transaction,
            :with_credit_card,
            user:,
            credit_card: card,
            description: "Closing",
            starts_on: Date.new(2026, 7, 25)
          )
          create(
            :transaction,
            :with_credit_card,
            user:,
            credit_card: card,
            description: "Next cycle",
            starts_on: Date.new(2026, 7, 26)
          )

          list_monthly_statements(month: 8, year: 2026)

          expect(descriptions).to contain_exactly("Opening", "Closing")
          expect(item_attributes).to all(
            include("opening_date" => "2026-06-26", "closing_date" => "2026-07-25", "due_date" => "2026-08-10")
          )
        end

        it "wraps the opening date to the previous year for a January statement" do
          create(
            :transaction,
            :with_credit_card,
            user:,
            credit_card:,
            description: "Opening",
            starts_on: Date.new(2025, 12, 11)
          )
          create(
            :transaction,
            :with_credit_card,
            user:,
            credit_card:,
            description: "Before opening",
            starts_on: Date.new(2025, 12, 10)
          )
          create(
            :transaction,
            :with_credit_card,
            user:,
            credit_card:,
            description: "Closing",
            starts_on: Date.new(2026, 1, 10)
          )
          create(
            :transaction,
            :with_credit_card,
            user:,
            credit_card:,
            description: "Next cycle",
            starts_on: Date.new(2026, 1, 11)
          )

          list_monthly_statements(month: 1, year: 2026)

          expect(descriptions).to contain_exactly("Opening", "Closing")
          expect(item_attributes).to all(
            include("opening_date" => "2025-12-11", "closing_date" => "2026-01-10", "due_date" => "2026-01-17")
          )
        end

        it "clamps closing and due dates when the card day does not exist in February" do
          card = create(:credit_card, user:, name: "Day 31", closing_day: 31, due_day: 31)
          create(
            :transaction,
            :with_credit_card,
            user:,
            credit_card: card,
            description: "Feb 28",
            starts_on: Date.new(2026, 2, 28)
          )
          create(
            :transaction,
            :with_credit_card,
            user:,
            credit_card: card,
            description: "Mar 1",
            starts_on: Date.new(2026, 3, 1)
          )

          list_monthly_statements(month: 2, year: 2026)

          expect(descriptions).to eq([ "Feb 28" ])
          expect(item_attributes.first).to include(
            "opening_date" => "2026-02-01",
            "closing_date" => "2026-02-28",
            "due_date" => "2026-02-28"
          )
        end

        it "opens on the day after the previous clamped close when February is shorter than closing_day" do
          card = create(:credit_card, user:, name: "Day 30", closing_day: 30, due_day: 31)
          create(
            :transaction,
            :with_credit_card,
            user:,
            credit_card: card,
            description: "Jan 30",
            starts_on: Date.new(2026, 1, 30)
          )
          create(
            :transaction,
            :with_credit_card,
            user:,
            credit_card: card,
            description: "Jan 31",
            starts_on: Date.new(2026, 1, 31)
          )
          create(
            :transaction,
            :with_credit_card,
            user:,
            credit_card: card,
            description: "Feb 28",
            starts_on: Date.new(2026, 2, 28)
          )
          create(
            :transaction,
            :with_credit_card,
            user:,
            credit_card: card,
            description: "Mar 1",
            starts_on: Date.new(2026, 3, 1)
          )

          list_monthly_statements(month: 2, year: 2026)

          expect(descriptions).to contain_exactly("Jan 31", "Feb 28")
          expect(item_attributes).to all(
            include("opening_date" => "2026-01-31", "closing_date" => "2026-02-28", "due_date" => "2026-02-28")
          )

          list_monthly_statements(month: 3, year: 2026)

          expect(descriptions).to eq([ "Mar 1" ])
          expect(item_attributes.first).to include(
            "opening_date" => "2026-03-01",
            "closing_date" => "2026-03-30",
            "due_date" => "2026-03-31"
          )
        end

        it "places a purchase on the day after a 30-day close on the next statement" do
          card = create(:credit_card, user:, name: "Day 30 next", closing_day: 30, due_day: 31)
          create(
            :transaction,
            :with_credit_card,
            user:,
            credit_card: card,
            description: "Mar 31",
            starts_on: Date.new(2026, 3, 31)
          )

          list_monthly_statements(month: 3, year: 2026)

          expect(descriptions).to eq([])

          list_monthly_statements(month: 4, year: 2026)

          expect(descriptions).to eq([ "Mar 31" ])
          expect(item_attributes.first).to include(
            "opening_date" => "2026-03-31",
            "closing_date" => "2026-04-30",
            "due_date" => "2026-04-30"
          )
        end

        it "does not overlap adjacent cycles when closing_day is after due_day across months of different length" do
          card = create(:credit_card, user:, name: "Late close 30", closing_day: 30, due_day: 10)
          create(
            :transaction,
            :with_credit_card,
            user:,
            credit_card: card,
            description: "May 31",
            starts_on: Date.new(2026, 5, 31)
          )
          create(
            :transaction,
            :with_credit_card,
            user:,
            credit_card: card,
            description: "Jun 30",
            starts_on: Date.new(2026, 6, 30)
          )
          create(
            :transaction,
            :with_credit_card,
            user:,
            credit_card: card,
            description: "Jul 1",
            starts_on: Date.new(2026, 7, 1)
          )

          list_monthly_statements(month: 7, year: 2026)

          expect(descriptions).to contain_exactly("May 31", "Jun 30")
          expect(item_attributes).to all(
            include("opening_date" => "2026-05-31", "closing_date" => "2026-06-30", "due_date" => "2026-07-10")
          )

          list_monthly_statements(month: 8, year: 2026)

          expect(descriptions).to eq([ "Jul 1" ])
          expect(item_attributes.first).to include(
            "opening_date" => "2026-07-01",
            "closing_date" => "2026-07-30",
            "due_date" => "2026-08-10"
          )
        end

        it "excludes January 31 from the January statement when closing_day is 30" do
          card = create(:credit_card, user:, name: "Day 30 jan", closing_day: 30, due_day: 31)
          create_card_purchase(card, "Jan 30", Date.new(2026, 1, 30))
          create_card_purchase(card, "Jan 31", Date.new(2026, 1, 31))

          list_monthly_statements(month: 1, year: 2026)

          expect(descriptions).to eq([ "Jan 30" ])
          expect(item_attributes.first).to include(
            "opening_date" => "2025-12-31",
            "closing_date" => "2026-01-30",
            "due_date" => "2026-01-31"
          )
        end

        it "does not drop January 29-31 when closing_day is 28" do
          card = create(:credit_card, user:, name: "Day 28", closing_day: 28, due_day: 31)
          create_card_purchase(card, "Jan 28", Date.new(2026, 1, 28))
          create_card_purchase(card, "Jan 29", Date.new(2026, 1, 29))
          create_card_purchase(card, "Jan 30", Date.new(2026, 1, 30))
          create_card_purchase(card, "Jan 31", Date.new(2026, 1, 31))
          create_card_purchase(card, "Feb 28", Date.new(2026, 2, 28))
          create_card_purchase(card, "Mar 1", Date.new(2026, 3, 1))

          list_monthly_statements(month: 1, year: 2026)

          expect(descriptions).to eq([ "Jan 28" ])
          expect(item_attributes.first).to include(
            "opening_date" => "2025-12-29",
            "closing_date" => "2026-01-28",
            "due_date" => "2026-01-31"
          )

          list_monthly_statements(month: 2, year: 2026)

          expect(descriptions).to contain_exactly("Jan 29", "Jan 30", "Jan 31", "Feb 28")
          expect(item_attributes).to all(
            include("opening_date" => "2026-01-29", "closing_date" => "2026-02-28", "due_date" => "2026-02-28")
          )

          list_monthly_statements(month: 3, year: 2026)

          expect(descriptions).to eq([ "Mar 1" ])
          expect(item_attributes.first).to include(
            "opening_date" => "2026-03-01",
            "closing_date" => "2026-03-28",
            "due_date" => "2026-03-31"
          )
        end

        it "does not drop January 30-31 when closing_day is 29" do
          card = create(:credit_card, user:, name: "Day 29", closing_day: 29, due_day: 31)
          create_card_purchase(card, "Jan 29", Date.new(2026, 1, 29))
          create_card_purchase(card, "Jan 30", Date.new(2026, 1, 30))
          create_card_purchase(card, "Jan 31", Date.new(2026, 1, 31))
          create_card_purchase(card, "Feb 28", Date.new(2026, 2, 28))
          create_card_purchase(card, "Mar 1", Date.new(2026, 3, 1))

          list_monthly_statements(month: 1, year: 2026)

          expect(descriptions).to eq([ "Jan 29" ])
          expect(item_attributes.first).to include(
            "opening_date" => "2025-12-30",
            "closing_date" => "2026-01-29",
            "due_date" => "2026-01-31"
          )

          list_monthly_statements(month: 2, year: 2026)

          expect(descriptions).to contain_exactly("Jan 30", "Jan 31", "Feb 28")
          expect(item_attributes).to all(
            include("opening_date" => "2026-01-30", "closing_date" => "2026-02-28", "due_date" => "2026-02-28")
          )

          list_monthly_statements(month: 3, year: 2026)

          expect(descriptions).to eq([ "Mar 1" ])
          expect(item_attributes.first).to include(
            "opening_date" => "2026-03-01",
            "closing_date" => "2026-03-29",
            "due_date" => "2026-03-31"
          )
        end

        it "does not list a February 28 purchase on the March statement when closing_day is 30" do
          card = create(:credit_card, user:, name: "Day 30 no overlap", closing_day: 30, due_day: 31)
          create_card_purchase(card, "Feb 28", Date.new(2026, 2, 28))

          list_monthly_statements(month: 2, year: 2026)

          expect(descriptions).to eq([ "Feb 28" ])

          list_monthly_statements(month: 3, year: 2026)

          expect(descriptions).to eq([])
        end

        it "places leap day on the February statement when closing_day is 29" do
          card = create(:credit_card, user:, name: "Leap 29", closing_day: 29, due_day: 31)
          create_card_purchase(card, "Jan 29", Date.new(2028, 1, 29))
          create_card_purchase(card, "Jan 30", Date.new(2028, 1, 30))
          create_card_purchase(card, "Feb 29", Date.new(2028, 2, 29))
          create_card_purchase(card, "Mar 1", Date.new(2028, 3, 1))

          list_monthly_statements(month: 2, year: 2028)

          expect(descriptions).to contain_exactly("Jan 30", "Feb 29")
          expect(item_attributes).to all(
            include("opening_date" => "2028-01-30", "closing_date" => "2028-02-29", "due_date" => "2028-02-29")
          )

          list_monthly_statements(month: 3, year: 2028)

          expect(descriptions).to eq([ "Mar 1" ])
          expect(item_attributes.first).to include(
            "opening_date" => "2028-03-01",
            "closing_date" => "2028-03-29",
            "due_date" => "2028-03-31"
          )
        end

        it "places leap day on the February statement when closing_day is 30" do
          card = create(:credit_card, user:, name: "Leap 30", closing_day: 30, due_day: 31)
          create_card_purchase(card, "Feb 29", Date.new(2028, 2, 29))
          create_card_purchase(card, "Mar 1", Date.new(2028, 3, 1))

          list_monthly_statements(month: 2, year: 2028)

          expect(descriptions).to eq([ "Feb 29" ])
          expect(item_attributes.first).to include(
            "opening_date" => "2028-01-31",
            "closing_date" => "2028-02-29",
            "due_date" => "2028-02-29"
          )

          list_monthly_statements(month: 3, year: 2028)

          expect(descriptions).to eq([ "Mar 1" ])
          expect(item_attributes.first).to include(
            "opening_date" => "2028-03-01",
            "closing_date" => "2028-03-30",
            "due_date" => "2028-03-31"
          )
        end

        it "places leap day on the March statement when closing_day is 28" do
          card = create(:credit_card, user:, name: "Leap 28", closing_day: 28, due_day: 31)
          create_card_purchase(card, "Feb 28", Date.new(2028, 2, 28))
          create_card_purchase(card, "Feb 29", Date.new(2028, 2, 29))
          create_card_purchase(card, "Mar 1", Date.new(2028, 3, 1))

          list_monthly_statements(month: 2, year: 2028)

          expect(descriptions).to eq([ "Feb 28" ])
          expect(item_attributes.first).to include(
            "opening_date" => "2028-01-29",
            "closing_date" => "2028-02-28",
            "due_date" => "2028-02-29"
          )

          list_monthly_statements(month: 3, year: 2028)

          expect(descriptions).to contain_exactly("Feb 29", "Mar 1")
          expect(item_attributes).to all(
            include("opening_date" => "2028-02-29", "closing_date" => "2028-03-28", "due_date" => "2028-03-31")
          )
        end
      end

      context "recurrences" do
        it "uses the latest recurrence that starts on or before the period closing date" do
          transaction = create(
            :transaction,
            :recurring,
            user:,
            account:,
            description: "Internet",
            starts_on: Date.new(2026, 1, 10),
            value: 80
          )
          create(:transaction_recurrence, financial_transaction: transaction, starts_on: Date.new(2026, 8, 10), value: 90)
          create(:transaction_recurrence, financial_transaction: transaction, starts_on: Date.new(2026, 9, 10), value: 100)

          list_monthly_statements(month: 8, year: 2026)

          item = item_attributes.find { |row| row.fetch("id") == transaction.id }

          expect(item).to include(
            "value" => "90.0",
            "first_recurrence_on" => "2026-01-10",
            "current_recurrence_on" => "2026-08-10",
            "starts_on" => "2026-08-10",
            "recurrence_type" => "recurring"
          )
        end

        it "uses the latest credit card recurrence on or before the cycle closing date" do
          transaction = create(
            :transaction,
            :recurring,
            :with_credit_card,
            user:,
            credit_card:,
            description: "Streaming",
            starts_on: Date.new(2026, 1, 5),
            value: 30
          )
          create(:transaction_recurrence, financial_transaction: transaction, starts_on: Date.new(2026, 8, 10), value: 40)
          create(:transaction_recurrence, financial_transaction: transaction, starts_on: Date.new(2026, 9, 5), value: 50)

          list_monthly_statements(month: 8, year: 2026)

          item = item_attributes.find { |row| row.fetch("id") == transaction.id }

          expect(item).to include(
            "value" => "40.0",
            "first_recurrence_on" => "2026-01-05",
            "current_recurrence_on" => "2026-08-05",
            "starts_on" => "2026-08-10",
            "recurrence_type" => "recurring"
          )
        end

        it "includes recurring transactions that started before the period and have no end date" do
          create(
            :transaction,
            :recurring,
            user:,
            account:,
            description: "Still active",
            starts_on: Date.new(2025, 12, 10)
          )

          list_monthly_statements(month: 8, year: 2026)

          expect(descriptions).to eq([ "Still active" ])
        end

        it "excludes recurring transactions that ended before the current occurrence" do
          create(
            :transaction,
            :recurring,
            user:,
            account:,
            description: "Ended",
            starts_on: Date.new(2026, 1, 10),
            ends_on: Date.new(2026, 7, 31)
          )
          create(
            :transaction,
            :recurring,
            user:,
            account:,
            description: "Ended before occurrence",
            starts_on: Date.new(2026, 1, 10),
            ends_on: Date.new(2026, 8, 1)
          )
          create(
            :transaction,
            :recurring,
            user:,
            account:,
            description: "Ends on occurrence",
            starts_on: Date.new(2026, 1, 10),
            ends_on: Date.new(2026, 8, 10)
          )

          list_monthly_statements(month: 8, year: 2026)

          expect(descriptions).to eq([ "Ends on occurrence" ])
        end

        it "excludes credit card recurrences whose current occurrence is after ends_on" do
          create(
            :transaction,
            :recurring,
            :with_credit_card,
            user:,
            credit_card:,
            description: "Ended before occurrence",
            starts_on: Date.new(2026, 1, 5),
            ends_on: Date.new(2026, 7, 20)
          )
          create(
            :transaction,
            :recurring,
            :with_credit_card,
            user:,
            credit_card:,
            description: "Ends on occurrence",
            starts_on: Date.new(2026, 1, 5),
            ends_on: Date.new(2026, 8, 5)
          )

          list_monthly_statements(month: 8, year: 2026)

          expect(descriptions).to eq([ "Ends on occurrence" ])
          expect(item_attributes.first).to include("current_recurrence_on" => "2026-08-05")
        end

        it "excludes recurring transactions that start after the period closing date" do
          create(
            :transaction,
            :recurring,
            user:,
            account:,
            description: "Future",
            starts_on: Date.new(2026, 9, 1)
          )
          create(
            :transaction,
            :recurring,
            user:,
            account:,
            description: "Current",
            starts_on: Date.new(2026, 8, 31)
          )

          list_monthly_statements(month: 8, year: 2026)

          expect(descriptions).to eq(%w[Current])
        end

        it "excludes transactions that ended before the period opening date" do
          create(
            :transaction,
            :installment,
            user:,
            account:,
            description: "Ended",
            starts_on: Date.new(2026, 6, 1),
            ends_on: Date.new(2026, 7, 31),
            installments_count: 2
          )
          create(:transaction, user:, account:, description: "Current", starts_on: Date.new(2026, 8, 1))

          list_monthly_statements(month: 8, year: 2026)

          expect(descriptions).to eq(%w[Current])
        end

        it "includes installments that overlap the period" do
          create(
            :transaction,
            :installment,
            user:,
            account:,
            description: "Overlap",
            starts_on: Date.new(2026, 7, 15),
            ends_on: Date.new(2026, 8, 15),
            installments_count: 2
          )

          list_monthly_statements(month: 8, year: 2026)

          expect(item_attributes.first).to include(
            "description" => "Overlap",
            "recurrence_type" => "installment",
            "ends_on" => "2026-08-15"
          )
        end

        it "excludes credit card installments that ended before the cycle opening date" do
          create(
            :transaction,
            :installment,
            :with_credit_card,
            user:,
            credit_card:,
            description: "Ended",
            starts_on: Date.new(2026, 6, 10),
            ends_on: Date.new(2026, 7, 10),
            installments_count: 2
          )
          create(
            :transaction,
            :installment,
            :with_credit_card,
            user:,
            credit_card:,
            description: "Overlap",
            starts_on: Date.new(2026, 7, 11),
            ends_on: Date.new(2026, 8, 11),
            installments_count: 2
          )

          list_monthly_statements(month: 8, year: 2026)

          expect(descriptions).to eq(%w[Overlap])
        end

        it "projects a day-28 credit card recurrence onto March after a February close on the 28th" do
          card = create(:credit_card, user:, name: "Day 30 sub", closing_day: 30, due_day: 31)
          create(
            :transaction,
            :recurring,
            :with_credit_card,
            user:,
            credit_card: card,
            description: "Sub day 28",
            starts_on: Date.new(2026, 1, 28)
          )

          list_monthly_statements(month: 2, year: 2026)

          expect(item_attributes.first).to include(
            "description" => "Sub day 28",
            "current_recurrence_on" => "2026-02-28",
            "opening_date" => "2026-01-31",
            "closing_date" => "2026-02-28"
          )

          list_monthly_statements(month: 3, year: 2026)

          expect(item_attributes.first).to include(
            "description" => "Sub day 28",
            "current_recurrence_on" => "2026-03-28",
            "opening_date" => "2026-03-01",
            "closing_date" => "2026-03-30"
          )
        end

        it "does not include a credit card recurrence before its first starts_on" do
          card = create(:credit_card, user:, name: "Starts Mar 28", closing_day: 30, due_day: 31)
          create(
            :transaction,
            :recurring,
            :with_credit_card,
            user:,
            credit_card: card,
            description: "Starts Mar 28",
            starts_on: Date.new(2026, 3, 28)
          )

          list_monthly_statements(month: 2, year: 2026)

          expect(descriptions).to eq([])

          list_monthly_statements(month: 3, year: 2026)

          expect(item_attributes.first).to include(
            "description" => "Starts Mar 28",
            "first_recurrence_on" => "2026-03-28",
            "current_recurrence_on" => "2026-03-28",
            "opening_date" => "2026-03-01"
          )
        end

        it "shifts a day-31 recurrence to the cycle opening when it would fall after closing_day" do
          card = create(:credit_card, user:, name: "Day 31 sub", closing_day: 30, due_day: 31)
          create(
            :transaction,
            :recurring,
            :with_credit_card,
            user:,
            credit_card: card,
            description: "Day 31",
            starts_on: Date.new(2026, 1, 31)
          )

          {
            2 => { current: "2026-01-31", opening: "2026-01-31", closing: "2026-02-28" },
            3 => { current: "2026-03-01", opening: "2026-03-01", closing: "2026-03-30" },
            4 => { current: "2026-03-31", opening: "2026-03-31", closing: "2026-04-30" },
            5 => { current: "2026-05-01", opening: "2026-05-01", closing: "2026-05-30" },
            6 => { current: "2026-05-31", opening: "2026-05-31", closing: "2026-06-30" },
            7 => { current: "2026-07-01", opening: "2026-07-01", closing: "2026-07-30" },
            10 => { current: "2026-10-01", opening: "2026-10-01", closing: "2026-10-30" },
            12 => { current: "2026-12-01", opening: "2026-12-01", closing: "2026-12-30" }
          }.each do |month, dates|
            list_monthly_statements(month:, year: 2026)

            expect(item_attributes.first).to include(
              "description" => "Day 31",
              "current_recurrence_on" => dates.fetch(:current),
              "opening_date" => dates.fetch(:opening),
              "closing_date" => dates.fetch(:closing)
            )
          end
        end

        it "keeps a day-31 installment that ends on February 28 on the March statement when closing_day is 30" do
          card = create(:credit_card, user:, name: "Inst 31-28", closing_day: 30, due_day: 31)
          create(
            :transaction,
            :installment,
            :with_credit_card,
            user:,
            credit_card: card,
            description: "Installment 31-28",
            starts_on: Date.new(2026, 1, 31),
            ends_on: Date.new(2026, 2, 28),
            installments_count: 2
          )

          list_monthly_statements(month: 2, year: 2026)

          expect(item_attributes.first).to include(
            "description" => "Installment 31-28",
            "current_recurrence_on" => "2026-01-31",
            "ends_on" => "2026-02-28",
            "opening_date" => "2026-01-31",
            "closing_date" => "2026-02-28"
          )

          list_monthly_statements(month: 3, year: 2026)

          expect(item_attributes.first).to include(
            "description" => "Installment 31-28",
            "current_recurrence_on" => "2026-03-01",
            "ends_on" => "2026-02-28",
            "opening_date" => "2026-03-01",
            "closing_date" => "2026-03-30"
          )

          list_monthly_statements(month: 4, year: 2026)

          expect(descriptions).to eq([])
        end

        it "keeps a day-31 recurring transaction that ends on February 28 on the March statement when closing_day is 30" do
          card = create(:credit_card, user:, name: "Rec 31-28", closing_day: 30, due_day: 31)
          create(
            :transaction,
            :recurring,
            :with_credit_card,
            user:,
            credit_card: card,
            description: "Recurring 31-28",
            starts_on: Date.new(2026, 1, 31),
            ends_on: Date.new(2026, 2, 28)
          )

          list_monthly_statements(month: 2, year: 2026)

          expect(item_attributes.first).to include(
            "description" => "Recurring 31-28",
            "current_recurrence_on" => "2026-01-31"
          )

          list_monthly_statements(month: 3, year: 2026)

          expect(item_attributes.first).to include(
            "description" => "Recurring 31-28",
            "current_recurrence_on" => "2026-03-01"
          )

          list_monthly_statements(month: 4, year: 2026)

          expect(descriptions).to eq([])
        end

        it "keeps a day-31 installment that ends on April 30 on the May statement when closing_day is 30" do
          card = create(:credit_card, user:, name: "Inst 31-30", closing_day: 30, due_day: 31)
          create(
            :transaction,
            :installment,
            :with_credit_card,
            user:,
            credit_card: card,
            description: "Installment Mar-Apr",
            starts_on: Date.new(2026, 3, 31),
            ends_on: Date.new(2026, 4, 30),
            installments_count: 2
          )

          list_monthly_statements(month: 4, year: 2026)

          expect(item_attributes.first).to include(
            "description" => "Installment Mar-Apr",
            "current_recurrence_on" => "2026-03-31",
            "opening_date" => "2026-03-31",
            "closing_date" => "2026-04-30"
          )

          list_monthly_statements(month: 5, year: 2026)

          expect(item_attributes.first).to include(
            "description" => "Installment Mar-Apr",
            "current_recurrence_on" => "2026-05-01",
            "opening_date" => "2026-05-01",
            "closing_date" => "2026-05-30"
          )

          list_monthly_statements(month: 6, year: 2026)

          expect(descriptions).to eq([])
        end

        it "projects a day-29 credit card recurrence onto March after February" do
          card = create(:credit_card, user:, name: "Day 29 sub", closing_day: 29, due_day: 31)
          create_card_purchase(card, "Sub day 29", Date.new(2026, 1, 29), :recurring)

          list_monthly_statements(month: 2, year: 2026)

          expect(item_attributes.first).to include(
            "description" => "Sub day 29",
            "current_recurrence_on" => "2026-02-28",
            "opening_date" => "2026-01-30",
            "closing_date" => "2026-02-28"
          )

          list_monthly_statements(month: 3, year: 2026)

          expect(item_attributes.first).to include(
            "description" => "Sub day 29",
            "current_recurrence_on" => "2026-03-29",
            "opening_date" => "2026-03-01",
            "closing_date" => "2026-03-29"
          )
        end

        it "projects a day-30 credit card recurrence onto March after February" do
          card = create(:credit_card, user:, name: "Day 30 rec", closing_day: 30, due_day: 31)
          create_card_purchase(card, "Sub day 30", Date.new(2026, 1, 30), :recurring)

          list_monthly_statements(month: 2, year: 2026)

          expect(item_attributes.first).to include(
            "description" => "Sub day 30",
            "current_recurrence_on" => "2026-02-28",
            "opening_date" => "2026-01-31",
            "closing_date" => "2026-02-28"
          )

          list_monthly_statements(month: 3, year: 2026)

          expect(item_attributes.first).to include(
            "description" => "Sub day 30",
            "current_recurrence_on" => "2026-03-30",
            "opening_date" => "2026-03-01",
            "closing_date" => "2026-03-30"
          )
        end

        it "projects a day-28 credit card recurrence onto March when closing_day is 28" do
          card = create(:credit_card, user:, name: "Day 28 sub", closing_day: 28, due_day: 31)
          create_card_purchase(card, "Sub day 28 close 28", Date.new(2026, 1, 28), :recurring)

          list_monthly_statements(month: 2, year: 2026)

          expect(item_attributes.first).to include(
            "description" => "Sub day 28 close 28",
            "current_recurrence_on" => "2026-02-28",
            "opening_date" => "2026-01-29",
            "closing_date" => "2026-02-28"
          )

          list_monthly_statements(month: 3, year: 2026)

          expect(item_attributes.first).to include(
            "description" => "Sub day 28 close 28",
            "current_recurrence_on" => "2026-03-28",
            "opening_date" => "2026-03-01",
            "closing_date" => "2026-03-28"
          )
        end

        it "does not include a day-29 recurrence before its first starts_on" do
          card = create(:credit_card, user:, name: "Starts Mar 29", closing_day: 29, due_day: 31)
          create_card_purchase(card, "Starts Mar 29", Date.new(2026, 3, 29), :recurring)

          list_monthly_statements(month: 2, year: 2026)

          expect(descriptions).to eq([])

          list_monthly_statements(month: 3, year: 2026)

          expect(item_attributes.first).to include(
            "description" => "Starts Mar 29",
            "first_recurrence_on" => "2026-03-29",
            "current_recurrence_on" => "2026-03-29",
            "opening_date" => "2026-03-01"
          )
        end

        it "does not include a day-30 recurrence before its first starts_on" do
          card = create(:credit_card, user:, name: "Starts Mar 30", closing_day: 30, due_day: 31)
          create_card_purchase(card, "Starts Mar 30", Date.new(2026, 3, 30), :recurring)

          list_monthly_statements(month: 2, year: 2026)

          expect(descriptions).to eq([])

          list_monthly_statements(month: 3, year: 2026)

          expect(item_attributes.first).to include(
            "description" => "Starts Mar 30",
            "first_recurrence_on" => "2026-03-30",
            "current_recurrence_on" => "2026-03-30",
            "opening_date" => "2026-03-01"
          )
        end

        it "does not project a March one-time onto February when the cycle opens on March 1" do
          card = create(:credit_card, user:, name: "Mar 28 one-time", closing_day: 30, due_day: 31)
          create_card_purchase(card, "Mar 28", Date.new(2026, 3, 28))

          list_monthly_statements(month: 2, year: 2026)

          expect(descriptions).to eq([])

          list_monthly_statements(month: 3, year: 2026)

          expect(item_attributes.first).to include(
            "description" => "Mar 28",
            "first_recurrence_on" => "2026-03-28",
            "current_recurrence_on" => "2026-03-28",
            "opening_date" => "2026-03-01",
            "closing_date" => "2026-03-30"
          )
        end

        it "projects a day-29 recurrence onto leap day in February 2028" do
          card = create(:credit_card, user:, name: "Leap 29 sub", closing_day: 29, due_day: 31)
          create_card_purchase(card, "Sub leap 29", Date.new(2028, 1, 29), :recurring)

          list_monthly_statements(month: 2, year: 2028)

          expect(item_attributes.first).to include(
            "description" => "Sub leap 29",
            "current_recurrence_on" => "2028-02-29",
            "opening_date" => "2028-01-30",
            "closing_date" => "2028-02-29"
          )

          list_monthly_statements(month: 3, year: 2028)

          expect(item_attributes.first).to include(
            "description" => "Sub leap 29",
            "current_recurrence_on" => "2028-03-29",
            "opening_date" => "2028-03-01",
            "closing_date" => "2028-03-29"
          )
        end
      end

      context "cancellations and statuses" do
        it "excludes transactions canceled before the period opening date" do
          create(
            :transaction,
            :canceled,
            user:,
            account:,
            description: "Canceled",
            starts_on: Date.new(2026, 8, 11),
            canceled_on: Date.new(2026, 7, 31)
          )
          create(:transaction, user:, account:, description: "Current", starts_on: Date.new(2026, 8, 1))

          list_monthly_statements(month: 8, year: 2026)

          expect(descriptions).to eq(%w[Current])
        end

        it "includes transactions canceled on or after the current occurrence" do
          create(
            :transaction,
            :canceled,
            user:,
            account:,
            description: "Canceled before occurrence",
            starts_on: Date.new(2026, 8, 11),
            canceled_on: Date.new(2026, 8, 1)
          )
          create(
            :transaction,
            :canceled,
            user:,
            account:,
            description: "Canceled on occurrence",
            starts_on: Date.new(2026, 8, 11),
            canceled_on: Date.new(2026, 8, 11)
          )
          create(
            :transaction,
            :canceled,
            user:,
            account:,
            description: "Canceled later",
            starts_on: Date.new(2026, 8, 11),
            canceled_on: Date.new(2026, 8, 15)
          )

          list_monthly_statements(month: 8, year: 2026)

          by_description = item_attributes.index_by { |item| item.fetch("description") }

          expect(by_description.keys).to contain_exactly("Canceled on occurrence", "Canceled later")
          expect(by_description.fetch("Canceled on occurrence")).to include("canceled_on" => "2026-08-11")
          expect(by_description.fetch("Canceled later")).to include("canceled_on" => "2026-08-15")
        end

        it "includes pending, active, and completed transactions" do
          create(:transaction, user:, account:, description: "Pending", starts_on: Date.new(2026, 8, 11))
          create(:transaction, :active, user:, account:, description: "Active", starts_on: Date.new(2026, 8, 11))
          create(:transaction, :completed, user:, account:, description: "Completed", starts_on: Date.new(2026, 8, 11))

          list_monthly_statements(month: 8, year: 2026)

          expect(descriptions).to contain_exactly("Pending", "Active", "Completed")
        end

        it "excludes credit card transactions canceled before the billing cycle opening date" do
          create(
            :transaction,
            :canceled,
            :with_credit_card,
            user:,
            credit_card:,
            description: "Canceled",
            starts_on: Date.new(2026, 8, 1),
            canceled_on: Date.new(2026, 7, 10)
          )
          create(
            :transaction,
            :with_credit_card,
            user:,
            credit_card:,
            description: "This cycle",
            starts_on: Date.new(2026, 8, 10)
          )

          list_monthly_statements(month: 8, year: 2026)

          expect(descriptions).to eq([ "This cycle" ])
        end

        it "includes credit card transactions canceled on or after the current occurrence" do
          create(
            :transaction,
            :canceled,
            :with_credit_card,
            user:,
            credit_card:,
            description: "Canceled before occurrence",
            starts_on: Date.new(2026, 8, 1),
            canceled_on: Date.new(2026, 7, 11)
          )
          create(
            :transaction,
            :canceled,
            :with_credit_card,
            user:,
            credit_card:,
            description: "Canceled on occurrence",
            starts_on: Date.new(2026, 8, 1),
            canceled_on: Date.new(2026, 8, 1)
          )
          create(
            :transaction,
            :canceled,
            :with_credit_card,
            user:,
            credit_card:,
            description: "Canceled during cycle",
            starts_on: Date.new(2026, 8, 1),
            canceled_on: Date.new(2026, 8, 5)
          )

          list_monthly_statements(month: 8, year: 2026)

          by_description = item_attributes.index_by { |item| item.fetch("description") }

          expect(by_description.keys).to contain_exactly("Canceled on occurrence", "Canceled during cycle")
          expect(by_description.fetch("Canceled on occurrence")).to include(
            "current_recurrence_on" => "2026-08-01",
            "canceled_on" => "2026-08-01"
          )
          expect(by_description.fetch("Canceled during cycle")).to include("canceled_on" => "2026-08-05")
        end
      end

      it "returns an empty collection when there are no matching transactions" do
        list_monthly_statements(month: 8, year: 2026)

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["data"]).to eq([])
      end

      it "returns 422 when month is missing" do
        list_monthly_statements(year: 2026)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "month")).to be_present
      end

      it "returns 422 when year is missing" do
        list_monthly_statements(month: 8)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "year")).to be_present
      end

      it "returns 422 for an invalid month" do
        list_monthly_statements(month: 13, year: 2026)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "month")).to be_present
      end

      it "returns 422 for month 0" do
        list_monthly_statements(month: 0, year: 2026)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "month")).to be_present
      end

      it "returns 422 for year 0" do
        list_monthly_statements(month: 8, year: 0)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "year")).to be_present
      end

      it "returns 422 for a year above 9999" do
        list_monthly_statements(month: 8, year: 10_000)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "year")).to be_present
      end
    end

    context "when unauthenticated" do
      subject { list_monthly_statements({ month: 8, year: 2026 }, {}) }

      it_behaves_like "an unauthorized API request"
    end
  end
end
