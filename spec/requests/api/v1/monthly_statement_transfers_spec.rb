require "rails_helper"

RSpec.describe "API::V1::MonthlyStatement::Transfers", type: :request do
  let(:user) { create(:user, :verified) }
  let(:headers) { auth_headers_for(user) }
  let(:source_account) { create(:account, user:, name: "Checking") }
  let(:destination_account) { create(:account, user:, name: "Savings") }

  def list_monthly_statement_transfers(query = {}, request_headers = headers)
    get "/api/v1/monthly_statements/transfers", params: query, headers: request_headers
  end

  def item_attributes(payload = response.parsed_body)
    payload.fetch("data").map { |item| item.fetch("attributes") }
  end

  def descriptions
    item_attributes.map { |item| item.fetch("description") }
  end

  describe "GET /api/v1/monthly_statements/transfers" do
    context "when authenticated" do
      it "returns transfers with source and destination accounts for the given period" do
        transfer = create(
          :transaction,
          :transfer,
          user:,
          source_account:,
          destination_account:,
          description: "Move to savings",
          starts_on: Date.new(2026, 8, 11),
          value: 150
        )

        list_monthly_statement_transfers(month: 8, year: 2026)

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["type"]).to eq("collection")
        expect(response.parsed_body.dig("data", 0, "type")).to eq("monthly_statement_transfer")
        expect(item_attributes).to contain_exactly(
          hash_including(
            "id" => transfer.id,
            "kind" => "transfer_between_accounts",
            "description" => "Move to savings",
            "recurrence_type" => "one_time",
            "source_account_id" => source_account.id,
            "source_account_name" => "Checking",
            "source_account_brand" => "#3B82F6",
            "destination_account_id" => destination_account.id,
            "destination_account_name" => "Savings",
            "destination_account_brand" => "#3B82F6",
            "opening_date" => "2026-08-01",
            "closing_date" => "2026-08-31",
            "value" => "150.0",
            "first_recurrence_on" => "2026-08-11",
            "current_recurrence_on" => "2026-08-11",
            "starts_on" => "2026-08-11",
            "ends_on" => nil,
            "canceled_on" => nil
          )
        )
      end

      it "uses the institution logo as brand for bank accounts" do
        source = create(:account, :bank_account, user:, name: "Bradesco")
        destination = create(:account, :bank_account, user:, name: "Nubank")
        create(
          :transaction,
          :transfer,
          user:,
          source_account: source,
          destination_account: destination,
          description: "Bank transfer",
          starts_on: Date.new(2026, 8, 11)
        )

        list_monthly_statement_transfers(month: 8, year: 2026)

        expect(item_attributes.first).to include(
          "source_account_id" => source.id,
          "source_account_name" => "Bradesco",
          "source_account_brand" => source.institution.logo_key,
          "destination_account_id" => destination.id,
          "destination_account_name" => "Nubank",
          "destination_account_brand" => destination.institution.logo_key
        )
      end

      it "does not return income, expense, or credit card transactions" do
        create(:transaction, user:, account: source_account, description: "Rent", starts_on: Date.new(2026, 8, 11))
        create(:transaction, :income, user:, account: source_account, description: "Salary", starts_on: Date.new(2026, 8, 11))
        create(:transaction, :with_credit_card, user:, description: "Grocery", starts_on: Date.new(2026, 8, 1))
        create(
          :transaction,
          :transfer,
          user:,
          source_account:,
          destination_account:,
          description: "Transfer",
          starts_on: Date.new(2026, 8, 11)
        )

        list_monthly_statement_transfers(month: 8, year: 2026)

        expect(descriptions).to eq(%w[Transfer])
      end

      it "includes transfers on inactive accounts" do
        inactive_source = create(:account, :inactive, user:, name: "Old wallet")
        inactive_destination = create(:account, :inactive, user:, name: "Old savings")
        create(
          :transaction,
          :transfer,
          user:,
          source_account: inactive_source,
          destination_account: inactive_destination,
          description: "Old transfer",
          starts_on: Date.new(2026, 8, 11)
        )

        list_monthly_statement_transfers(month: 8, year: 2026)

        expect(descriptions).to eq([ "Old transfer" ])
      end

      it "does not return another user's transfers" do
        create(
          :transaction,
          :transfer,
          user:,
          source_account:,
          destination_account:,
          description: "Mine",
          starts_on: Date.new(2026, 8, 11)
        )
        create(:transaction, :transfer, description: "Other", starts_on: Date.new(2026, 8, 11))

        list_monthly_statement_transfers(month: 8, year: 2026)

        expect(response).to have_http_status(:ok)
        expect(descriptions).to eq(%w[Mine])
      end

      it "excludes transfers that have no recurrences" do
        transfer = create(
          :transaction,
          :transfer,
          user:,
          with_links: false,
          description: "Orphan"
        )
        Transaction::ForTransferBetweenAccounts::Record.create!(
          financial_transaction: transfer,
          source_account:,
          destination_account:
        )
        create(
          :transaction,
          :transfer,
          user:,
          source_account:,
          destination_account:,
          description: "Current",
          starts_on: Date.new(2026, 8, 11)
        )

        list_monthly_statement_transfers(month: 8, year: 2026)

        expect(descriptions).to eq(%w[Current])
      end

      context "account calendar period" do
        it "includes one-time transfers on the first and last day of the month" do
          create(
            :transaction,
            :transfer,
            user:,
            source_account:,
            destination_account:,
            description: "First day",
            starts_on: Date.new(2026, 8, 1)
          )
          create(
            :transaction,
            :transfer,
            user:,
            source_account:,
            destination_account:,
            description: "Last day",
            starts_on: Date.new(2026, 8, 31)
          )

          list_monthly_statement_transfers(month: 8, year: 2026)

          expect(descriptions).to contain_exactly("First day", "Last day")
          expect(item_attributes).to all(include("opening_date" => "2026-08-01", "closing_date" => "2026-08-31"))
        end

        it "excludes one-time transfers from the previous and next months" do
          create(
            :transaction,
            :transfer,
            user:,
            source_account:,
            destination_account:,
            description: "July",
            starts_on: Date.new(2026, 7, 31)
          )
          create(
            :transaction,
            :transfer,
            user:,
            source_account:,
            destination_account:,
            description: "August",
            starts_on: Date.new(2026, 8, 15)
          )
          create(
            :transaction,
            :transfer,
            user:,
            source_account:,
            destination_account:,
            description: "September",
            starts_on: Date.new(2026, 9, 1)
          )

          list_monthly_statement_transfers(month: 8, year: 2026)

          expect(descriptions).to eq(%w[August])
        end

        it "clamps the closing date to the last day of February" do
          create(
            :transaction,
            :transfer,
            user:,
            source_account:,
            destination_account:,
            description: "Feb 28",
            starts_on: Date.new(2026, 2, 28)
          )
          create(
            :transaction,
            :transfer,
            user:,
            source_account:,
            destination_account:,
            description: "Mar 1",
            starts_on: Date.new(2026, 3, 1)
          )

          list_monthly_statement_transfers(month: 2, year: 2026)

          expect(descriptions).to eq([ "Feb 28" ])
          expect(item_attributes.first).to include("opening_date" => "2026-02-01", "closing_date" => "2026-02-28")
        end

        it "includes February 29 on a leap year" do
          create(
            :transaction,
            :transfer,
            user:,
            source_account:,
            destination_account:,
            description: "Leap day",
            starts_on: Date.new(2028, 2, 29)
          )
          create(
            :transaction,
            :transfer,
            user:,
            source_account:,
            destination_account:,
            description: "Mar 1",
            starts_on: Date.new(2028, 3, 1)
          )

          list_monthly_statement_transfers(month: 2, year: 2028)

          expect(descriptions).to eq([ "Leap day" ])
          expect(item_attributes.first).to include("opening_date" => "2028-02-01", "closing_date" => "2028-02-29")
        end
      end

      context "recurrences" do
        it "uses the latest recurrence that starts on or before the period closing date" do
          transfer = create(
            :transaction,
            :transfer,
            :recurring,
            user:,
            source_account:,
            destination_account:,
            description: "Allowance",
            starts_on: Date.new(2026, 1, 10),
            value: 80
          )
          create(:transaction_recurrence, financial_transaction: transfer, starts_on: Date.new(2026, 8, 10), value: 90)
          create(:transaction_recurrence, financial_transaction: transfer, starts_on: Date.new(2026, 9, 10), value: 100)

          list_monthly_statement_transfers(month: 8, year: 2026)

          item = item_attributes.find { |row| row.fetch("id") == transfer.id }

          expect(item).to include(
            "value" => "90.0",
            "first_recurrence_on" => "2026-01-10",
            "current_recurrence_on" => "2026-08-10",
            "starts_on" => "2026-08-10",
            "recurrence_type" => "recurring"
          )
        end

        it "includes recurring transfers that started before the period and have no end date" do
          create(
            :transaction,
            :transfer,
            :recurring,
            user:,
            source_account:,
            destination_account:,
            description: "Still active",
            starts_on: Date.new(2025, 12, 10)
          )

          list_monthly_statement_transfers(month: 8, year: 2026)

          expect(descriptions).to eq([ "Still active" ])
        end

        it "excludes recurring transfers that ended before the current occurrence" do
          create(
            :transaction,
            :transfer,
            :recurring,
            user:,
            source_account:,
            destination_account:,
            description: "Ended",
            starts_on: Date.new(2026, 1, 10),
            ends_on: Date.new(2026, 7, 31)
          )
          create(
            :transaction,
            :transfer,
            :recurring,
            user:,
            source_account:,
            destination_account:,
            description: "Ended before occurrence",
            starts_on: Date.new(2026, 1, 10),
            ends_on: Date.new(2026, 8, 1)
          )
          create(
            :transaction,
            :transfer,
            :recurring,
            user:,
            source_account:,
            destination_account:,
            description: "Ends on occurrence",
            starts_on: Date.new(2026, 1, 10),
            ends_on: Date.new(2026, 8, 10)
          )

          list_monthly_statement_transfers(month: 8, year: 2026)

          expect(descriptions).to eq([ "Ends on occurrence" ])
        end

        it "excludes recurring transfers that start after the period closing date" do
          create(
            :transaction,
            :transfer,
            :recurring,
            user:,
            source_account:,
            destination_account:,
            description: "Future",
            starts_on: Date.new(2026, 9, 1)
          )
          create(
            :transaction,
            :transfer,
            :recurring,
            user:,
            source_account:,
            destination_account:,
            description: "Current",
            starts_on: Date.new(2026, 8, 31)
          )

          list_monthly_statement_transfers(month: 8, year: 2026)

          expect(descriptions).to eq(%w[Current])
        end

        it "excludes transfers that ended before the period opening date" do
          create(
            :transaction,
            :transfer,
            :installment,
            user:,
            source_account:,
            destination_account:,
            description: "Ended",
            starts_on: Date.new(2026, 6, 1),
            ends_on: Date.new(2026, 7, 31),
            installments_count: 2
          )
          create(
            :transaction,
            :transfer,
            user:,
            source_account:,
            destination_account:,
            description: "Current",
            starts_on: Date.new(2026, 8, 1)
          )

          list_monthly_statement_transfers(month: 8, year: 2026)

          expect(descriptions).to eq(%w[Current])
        end

        it "includes installments that overlap the period" do
          create(
            :transaction,
            :transfer,
            :installment,
            user:,
            source_account:,
            destination_account:,
            description: "Overlap",
            starts_on: Date.new(2026, 7, 15),
            ends_on: Date.new(2026, 8, 15),
            installments_count: 2
          )

          list_monthly_statement_transfers(month: 8, year: 2026)

          expect(item_attributes.first).to include(
            "description" => "Overlap",
            "recurrence_type" => "installment",
            "ends_on" => "2026-08-15"
          )
        end
      end

      context "cancellations and statuses" do
        it "excludes transfers canceled before the period opening date" do
          create(
            :transaction,
            :transfer,
            :canceled,
            user:,
            source_account:,
            destination_account:,
            description: "Canceled",
            starts_on: Date.new(2026, 8, 11),
            canceled_on: Date.new(2026, 7, 31)
          )
          create(
            :transaction,
            :transfer,
            user:,
            source_account:,
            destination_account:,
            description: "Current",
            starts_on: Date.new(2026, 8, 1)
          )

          list_monthly_statement_transfers(month: 8, year: 2026)

          expect(descriptions).to eq(%w[Current])
        end

        it "includes transfers canceled on or after the current occurrence" do
          create(
            :transaction,
            :transfer,
            :canceled,
            user:,
            source_account:,
            destination_account:,
            description: "Canceled before occurrence",
            starts_on: Date.new(2026, 8, 11),
            canceled_on: Date.new(2026, 8, 1)
          )
          create(
            :transaction,
            :transfer,
            :canceled,
            user:,
            source_account:,
            destination_account:,
            description: "Canceled on occurrence",
            starts_on: Date.new(2026, 8, 11),
            canceled_on: Date.new(2026, 8, 11)
          )
          create(
            :transaction,
            :transfer,
            :canceled,
            user:,
            source_account:,
            destination_account:,
            description: "Canceled later",
            starts_on: Date.new(2026, 8, 11),
            canceled_on: Date.new(2026, 8, 15)
          )

          list_monthly_statement_transfers(month: 8, year: 2026)

          by_description = item_attributes.index_by { |item| item.fetch("description") }

          expect(by_description.keys).to contain_exactly("Canceled on occurrence", "Canceled later")
          expect(by_description.fetch("Canceled on occurrence")).to include("canceled_on" => "2026-08-11")
          expect(by_description.fetch("Canceled later")).to include("canceled_on" => "2026-08-15")
        end

        it "includes pending, active, and completed transfers" do
          create(
            :transaction,
            :transfer,
            user:,
            source_account:,
            destination_account:,
            description: "Pending",
            starts_on: Date.new(2026, 8, 11)
          )
          create(
            :transaction,
            :transfer,
            :active,
            user:,
            source_account:,
            destination_account:,
            description: "Active",
            starts_on: Date.new(2026, 8, 11)
          )
          create(
            :transaction,
            :transfer,
            :completed,
            user:,
            source_account:,
            destination_account:,
            description: "Completed",
            starts_on: Date.new(2026, 8, 11)
          )

          list_monthly_statement_transfers(month: 8, year: 2026)

          expect(descriptions).to contain_exactly("Pending", "Active", "Completed")
        end
      end

      it "returns an empty collection when there are no matching transfers" do
        list_monthly_statement_transfers(month: 8, year: 2026)

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["data"]).to eq([])
      end

      it "returns 422 when month is missing" do
        list_monthly_statement_transfers(year: 2026)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "month")).to be_present
      end

      it "returns 422 when year is missing" do
        list_monthly_statement_transfers(month: 8)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "year")).to be_present
      end

      it "returns 422 for an invalid month" do
        list_monthly_statement_transfers(month: 13, year: 2026)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "month")).to be_present
      end

      it "returns 422 for month 0" do
        list_monthly_statement_transfers(month: 0, year: 2026)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "month")).to be_present
      end

      it "returns 422 for year 0" do
        list_monthly_statement_transfers(month: 8, year: 0)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "year")).to be_present
      end

      it "returns 422 for a year above 9999" do
        list_monthly_statement_transfers(month: 8, year: 10_000)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "year")).to be_present
      end
    end

    context "when unauthenticated" do
      subject { list_monthly_statement_transfers({ month: 8, year: 2026 }, {}) }

      it_behaves_like "an unauthorized API request"
    end
  end
end
