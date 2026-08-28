require "rails_helper"

RSpec.describe "API::V1::Transaction::Recurrences", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let(:user) { create(:user, :verified) }
  let(:headers) { auth_headers_for(user) }
  let(:account) { create(:account, user:) }
  let(:category) { create(:category, user:) }
  let(:starts_on) { Date.new(2026, 8, 1) }
  let(:transaction) do
    create(:transaction, :recurring, :active, user:, account:, category:, starts_on:, value: 100)
  end

  around do |example|
    travel_to(Date.new(2026, 8, 14)) { example.run }
  end

  def transaction_attributes(payload)
    payload.dig("data", "attributes")
  end

  def transaction_recurrences(payload)
    Array(transaction_attributes(payload)["recurrences"]).map { |item| item.fetch("attributes") }
  end

  def recurrence_pairs(payload)
    transaction_recurrences(payload).map { |item| [ item["starts_on"], item["value"] ] }
  end

  def create_recurrence(transaction_id, params, request_headers = headers)
    post "/api/v1/transactions/#{transaction_id}/recurrences",
         params: { transaction_recurrence: params },
         headers: request_headers,
         as: :json
  end

  describe "POST /api/v1/transactions/:transaction_id/recurrences" do
    context "when authenticated" do
      context "when changing only the current month" do
        it "updates the existing recurrence and creates the next month with the old value" do
          transaction

          expect {
            create_recurrence(transaction.id, { value: 120, starts_on: "2026-08-01" })
          }.to change(Transaction::Recurrence::Record, :count).by(1)

          expect(response).to have_http_status(:ok)
          expect(response.parsed_body["message"]).to eq("Recurrence created or updated successfully")
          expect(recurrence_pairs(response.parsed_body)).to eq(
            [ [ "2026-08-01", "120.0" ], [ "2026-09-01", "100.0" ] ]
          )
        end

        it "creates a new recurrence for a different month and restores the old value afterwards" do
          transaction

          expect {
            create_recurrence(transaction.id, { value: 120, starts_on: "2026-10-01" })
          }.to change(Transaction::Recurrence::Record, :count).by(2)

          expect(response).to have_http_status(:ok)
          expect(recurrence_pairs(response.parsed_body)).to eq(
            [ [ "2026-08-01", "100.0" ], [ "2026-10-01", "120.0" ], [ "2026-11-01", "100.0" ] ]
          )
        end

        it "clamps a month-end change and restores the original day afterwards" do
          end_of_month_transaction = create(
            :transaction,
            :recurring,
            :active,
            user:,
            account:,
            category:,
            starts_on: Date.new(2026, 5, 31),
            value: 77
          )
          create(:transaction_recurrence, financial_transaction: end_of_month_transaction, starts_on: Date.new(2026, 8, 31), value: 78)

          expect {
            create_recurrence(end_of_month_transaction.id, { value: 79, starts_on: "2026-09-30" })
          }.to change(Transaction::Recurrence::Record, :count).by(2)

          expect(response).to have_http_status(:ok)
          expect(recurrence_pairs(response.parsed_body)).to eq(
            [
              [ "2026-05-31", "77.0" ],
              [ "2026-08-31", "78.0" ],
              [ "2026-09-30", "79.0" ],
              [ "2026-10-31", "78.0" ]
            ]
          )
        end

        it "updates the existing recurrence when starts_on is a different day in the same month" do
          transaction

          expect {
            create_recurrence(transaction.id, { value: 120, starts_on: "2026-08-15" })
          }.to change(Transaction::Recurrence::Record, :count).by(1)

          expect(response).to have_http_status(:ok)
          expect(recurrence_pairs(response.parsed_body)).to eq(
            [ [ "2026-08-15", "120.0" ], [ "2026-09-15", "100.0" ] ]
          )
        end

        it "does not create a next-month recurrence when one already exists" do
          create(:transaction_recurrence, financial_transaction: transaction, starts_on: Date.new(2026, 9, 1), value: 150)

          expect {
            create_recurrence(transaction.id, { value: 120, starts_on: "2026-08-01" })
          }.not_to change(Transaction::Recurrence::Record, :count)

          expect(response).to have_http_status(:ok)
          expect(recurrence_pairs(response.parsed_body)).to eq(
            [ [ "2026-08-01", "120.0" ], [ "2026-09-01", "150.0" ] ]
          )
        end

        it "does not create a next-month recurrence past the installment ends_on" do
          installment = create(
            :transaction,
            :installment,
            :active,
            user:,
            account:,
            category:,
            starts_on: Date.new(2026, 8, 1),
            ends_on: Date.new(2026, 9, 1),
            value: 100
          )
          create(:transaction_recurrence, financial_transaction: installment, starts_on: Date.new(2026, 9, 1), value: 100)

          expect {
            create_recurrence(installment.id, { value: 120, starts_on: "2026-09-01" })
          }.not_to change(Transaction::Recurrence::Record, :count)

          expect(response).to have_http_status(:ok)
          expect(recurrence_pairs(response.parsed_body)).to eq(
            [ [ "2026-08-01", "100.0" ], [ "2026-09-01", "120.0" ] ]
          )
        end
      end

      context "when changing the current and following months" do
        it "updates the existing recurrence without creating another record" do
          transaction

          expect {
            create_recurrence(
              transaction.id,
              { value: 120, starts_on: "2026-08-01", change_for_next_months: true }
            )
          }.not_to change(Transaction::Recurrence::Record, :count)

          expect(response).to have_http_status(:ok)
          expect(recurrence_pairs(response.parsed_body)).to eq(
            [ [ "2026-08-01", "120.0" ] ]
          )
        end

        it "creates a new recurrence for a different month and removes later recurrences" do
          transaction

          expect {
            create_recurrence(
              transaction.id,
              { value: 120, starts_on: "2026-10-01", change_for_next_months: true }
            )
          }.to change(Transaction::Recurrence::Record, :count).by(1)

          expect(response).to have_http_status(:ok)
          expect(recurrence_pairs(response.parsed_body)).to eq(
            [ [ "2026-08-01", "100.0" ], [ "2026-10-01", "120.0" ] ]
          )
        end

        it "does not restore the previous value in the next month" do
          end_of_month_transaction = create(
            :transaction,
            :recurring,
            :active,
            user:,
            account:,
            category:,
            starts_on: Date.new(2026, 5, 31),
            value: 77
          )
          create(:transaction_recurrence, financial_transaction: end_of_month_transaction, starts_on: Date.new(2026, 8, 31), value: 78)

          expect {
            create_recurrence(
              end_of_month_transaction.id,
              { value: 79, starts_on: "2026-09-30", change_for_next_months: true }
            )
          }.to change(Transaction::Recurrence::Record, :count).by(1)

          expect(response).to have_http_status(:ok)
          expect(recurrence_pairs(response.parsed_body)).to eq(
            [ [ "2026-05-31", "77.0" ], [ "2026-08-31", "78.0" ], [ "2026-09-30", "79.0" ] ]
          )
        end
      end

      context "with an existing recurrence timeline" do
        let(:transaction) do
          create(:transaction, :recurring, :active, user:, account:, category:, starts_on: Date.new(2026, 1, 1), value: 66)
        end

        before do
          create(:transaction_recurrence, financial_transaction: transaction, starts_on: Date.new(2026, 8, 1), value: 76)
          create(:transaction_recurrence, financial_transaction: transaction, starts_on: Date.new(2026, 9, 1), value: 86)
          create(:transaction_recurrence, financial_transaction: transaction, starts_on: Date.new(2026, 12, 1), value: 76)
        end

        it "updates the month and removes every later recurrence when change_for_next_months is true" do
          expect {
            create_recurrence(
              transaction.id,
              { value: 87, starts_on: "2026-09-01", change_for_next_months: true }
            )
          }.to change(Transaction::Recurrence::Record, :count).by(-1)

          expect(response).to have_http_status(:ok)
          expect(recurrence_pairs(response.parsed_body)).to eq(
            [ [ "2026-01-01", "66.0" ], [ "2026-08-01", "76.0" ], [ "2026-09-01", "87.0" ] ]
          )
        end

        it "updates the month, creates the next month with the previous value, and keeps later recurrences" do
          expect {
            create_recurrence(transaction.id, { value: 87, starts_on: "2026-09-01" })
          }.to change(Transaction::Recurrence::Record, :count).by(1)

          expect(response).to have_http_status(:ok)
          expect(recurrence_pairs(response.parsed_body)).to eq(
            [
              [ "2026-01-01", "66.0" ],
              [ "2026-08-01", "76.0" ],
              [ "2026-09-01", "87.0" ],
              [ "2026-10-01", "86.0" ],
              [ "2026-12-01", "76.0" ]
            ]
          )
        end

        it "keeps an existing next-month recurrence and later recurrences when change_for_next_months is false" do
          create(:transaction_recurrence, financial_transaction: transaction, starts_on: Date.new(2026, 10, 1), value: 90)

          expect {
            create_recurrence(transaction.id, { value: 87, starts_on: "2026-09-01" })
          }.not_to change(Transaction::Recurrence::Record, :count)

          expect(response).to have_http_status(:ok)
          expect(recurrence_pairs(response.parsed_body)).to eq(
            [
              [ "2026-01-01", "66.0" ],
              [ "2026-08-01", "76.0" ],
              [ "2026-09-01", "87.0" ],
              [ "2026-10-01", "90.0" ],
              [ "2026-12-01", "76.0" ]
            ]
          )
        end
      end

      context "when the month is before the current month" do
        let(:transaction) do
          create(:transaction, :recurring, :active, user:, account:, category:, starts_on: Date.new(2026, 1, 1), value: 100)
        end

        it "accepts the change" do
          create_recurrence(transaction.id, { value: 120, starts_on: "2026-01-01" })

          expect(response).to have_http_status(:ok)
          expect(recurrence_pairs(response.parsed_body)).to eq(
            [ [ "2026-01-01", "120.0" ], [ "2026-02-01", "100.0" ] ]
          )
        end
      end

      context "when the transaction is pending" do
        let(:transaction) do
          create(:transaction, :recurring, user:, account:, category:, starts_on:, value: 100)
        end

        it "rejects the change" do
          transaction

          expect {
            create_recurrence(transaction.id, { value: 120, starts_on: "2026-08-01" })
          }.not_to change(Transaction::Recurrence::Record, :count)

          expect(response).to have_http_status(:unprocessable_content)
          expect(response.parsed_body.dig("details", "base")).to eq(
            [ "Recurrence cannot be changed in the current status" ]
          )
        end
      end

      context "when the transaction is completed" do
        let(:transaction) do
          create(:transaction, :recurring, :completed, user:, account:, category:, starts_on:, value: 100)
        end

        it "rejects the change" do
          transaction

          expect {
            create_recurrence(transaction.id, { value: 120, starts_on: "2026-08-01" })
          }.not_to change(Transaction::Recurrence::Record, :count)

          expect(response).to have_http_status(:unprocessable_content)
          expect(response.parsed_body.dig("details", "base")).to eq(
            [ "Recurrence cannot be changed in the current status" ]
          )
        end
      end

      context "when the transaction is one-time" do
        let(:transaction) { create(:transaction, :active, user:, account:, category:, starts_on:, value: 100) }

        it "rejects the change" do
          create_recurrence(transaction.id, { value: 120, starts_on: "2026-08-01" })

          expect(response).to have_http_status(:unprocessable_content)
          expect(response.parsed_body.dig("details", "base")).to eq(
            [ "Recurrence value changes are not allowed for one-time transactions" ]
          )
        end
      end

      context "when the transaction consumes the credit card limit upfront" do
        let(:credit_card) { create(:credit_card, user:) }
        let(:transaction) do
          create(
            :transaction,
            :installment,
            :active,
            :with_credit_card,
            user:,
            category:,
            credit_card:,
            limit_consumption_type: "upfront",
            starts_on:,
            ends_on: Date.new(2026, 9, 1),
            value: 100
          )
        end

        it "rejects the change" do
          transaction

          expect {
            create_recurrence(transaction.id, { value: 120, starts_on: "2026-08-01" })
          }.not_to change(Transaction::Recurrence::Record, :count)

          expect(response).to have_http_status(:unprocessable_content)
          expect(response.parsed_body.dig("details", "base")).to eq(
            [ "Recurrence value cannot be changed when limit consumption is upfront" ]
          )
        end
      end

      context "when the transaction consumes the credit card limit monthly" do
        let(:credit_card) { create(:credit_card, user:) }
        let(:transaction) do
          create(
            :transaction,
            :installment,
            :active,
            :with_credit_card,
            user:,
            category:,
            credit_card:,
            limit_consumption_type: "monthly",
            starts_on:,
            ends_on: Date.new(2026, 9, 1),
            value: 100
          )
        end

        it "allows the change" do
          create(:transaction_recurrence, financial_transaction: transaction, starts_on: Date.new(2026, 9, 1), value: 100)

          expect {
            create_recurrence(transaction.id, { value: 120, starts_on: "2026-09-01" })
          }.not_to change(Transaction::Recurrence::Record, :count)

          expect(response).to have_http_status(:ok)
          expect(recurrence_pairs(response.parsed_body)).to eq(
            [ [ "2026-08-01", "100.0" ], [ "2026-09-01", "120.0" ] ]
          )
        end
      end

      it "rejects starts_on after ends_on" do
        installment = create(
          :transaction,
          :installment,
          :active,
          user:,
          account:,
          category:,
          starts_on: Date.new(2026, 8, 1),
          ends_on: Date.new(2026, 9, 1),
          value: 100
        )

        create_recurrence(installment.id, { value: 120, starts_on: "2026-10-01" })

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "starts_on")).to eq(
          [ "must be on or before ends_on" ]
        )
      end

      it "rejects a missing value" do
        create_recurrence(transaction.id, { starts_on: "2026-08-01" })

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "value")).to be_present
      end

      it "rejects the same value as the current month recurrence" do
        transaction

        expect {
          create_recurrence(transaction.id, { value: 100, starts_on: "2026-08-01" })
        }.not_to change(Transaction::Recurrence::Record, :count)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "value")).to eq(
          [ "must be different from the previous recurrence" ]
        )
      end

      it "rejects the same value as the previous recurrence for a later month" do
        transaction

        expect {
          create_recurrence(transaction.id, { value: 100, starts_on: "2026-10-01" })
        }.not_to change(Transaction::Recurrence::Record, :count)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "value")).to eq(
          [ "must be different from the previous recurrence" ]
        )
      end

      it "returns 404 for another user's transaction" do
        create_recurrence(create(:transaction, :recurring, :active).id, { value: 120, starts_on: "2026-08-01" })

        expect(response).to have_http_status(:not_found)
        expect(response.parsed_body["message"]).to eq("Transaction not found")
      end
    end

    context "when unauthenticated" do
      subject { create_recurrence(transaction.id, { value: 120, starts_on: "2026-08-01" }, {}) }

      it_behaves_like "an unauthorized API request"
    end
  end
end
