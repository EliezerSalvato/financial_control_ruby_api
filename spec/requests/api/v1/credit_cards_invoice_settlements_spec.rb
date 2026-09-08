require "rails_helper"

RSpec.describe "API::V1::CreditCards invoice_settlements", type: :request do
  let(:user) { create(:user, :verified) }
  let(:headers) { auth_headers_for(user) }
  let(:account) { create(:account, :bank_account, user:) }
  let(:credit_card) { create(:credit_card, user:, default_payment_account: account, name: "Nubank") }

  def list_invoice_settlements(query = {}, request_headers = headers)
    get "/api/v1/credit_cards/invoice_settlements", params: query, headers: request_headers
  end

  def item_attributes(payload = response.parsed_body)
    payload.fetch("data").map { |item| item.fetch("attributes") }
  end

  def due_dates
    item_attributes.map { |item| item.fetch("due_date") }
  end

  describe "GET /api/v1/credit_cards/invoice_settlements" do
    context "when authenticated" do
      it "returns invoices whose due_date falls in the given month" do
        invoice = create(
          :credit_card_invoice_settlement,
          credit_card:,
          payment_account: account,
          opening_date: Date.new(2026, 7, 11),
          closing_date: Date.new(2026, 8, 10),
          due_date: Date.new(2026, 8, 17),
          total_value: 250,
          released_limit: 250,
          settled_on: Date.new(2026, 8, 18)
        )

        list_invoice_settlements(month: 8, year: 2026)

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["type"]).to eq("collection")
        expect(response.parsed_body.dig("data", 0, "type")).to eq("credit_card_invoice_settlement")
        expect(item_attributes).to contain_exactly(
          hash_including(
            "id" => invoice.id,
            "credit_card_id" => credit_card.id,
            "payment_account_id" => account.id,
            "opening_date" => "2026-07-11",
            "closing_date" => "2026-08-10",
            "due_date" => "2026-08-17",
            "total_value" => "250.0",
            "released_limit" => "250.0",
            "settled_on" => "2026-08-18"
          )
        )
      end

      it "excludes invoices from the previous and next months" do
        create(
          :credit_card_invoice_settlement,
          credit_card:,
          payment_account: account,
          opening_date: Date.new(2026, 6, 11),
          closing_date: Date.new(2026, 7, 10),
          due_date: Date.new(2026, 7, 17),
          settled_on: Date.new(2026, 7, 17)
        )
        create(
          :credit_card_invoice_settlement,
          credit_card:,
          payment_account: account,
          due_date: Date.new(2026, 8, 17)
        )
        create(
          :credit_card_invoice_settlement,
          credit_card:,
          payment_account: account,
          opening_date: Date.new(2026, 8, 11),
          closing_date: Date.new(2026, 9, 10),
          due_date: Date.new(2026, 9, 17),
          settled_on: Date.new(2026, 9, 17)
        )

        list_invoice_settlements(month: 8, year: 2026)

        expect(due_dates).to eq([ "2026-08-17" ])
      end

      it "includes invoices on the first and last day of the month" do
        create(
          :credit_card_invoice_settlement,
          credit_card:,
          payment_account: account,
          due_date: Date.new(2026, 8, 1),
          settled_on: Date.new(2026, 8, 1)
        )
        other_card = create(:credit_card, user:, default_payment_account: account, closing_day: 10, due_day: 31)
        create(
          :credit_card_invoice_settlement,
          credit_card: other_card,
          payment_account: account,
          opening_date: Date.new(2026, 7, 25),
          closing_date: Date.new(2026, 8, 24),
          due_date: Date.new(2026, 8, 31),
          settled_on: Date.new(2026, 8, 31)
        )

        list_invoice_settlements(month: 8, year: 2026)

        expect(due_dates).to eq([ "2026-08-01", "2026-08-31" ])
      end

      it "includes February 29 on a leap year" do
        create(
          :credit_card_invoice_settlement,
          credit_card:,
          payment_account: account,
          opening_date: Date.new(2028, 1, 11),
          closing_date: Date.new(2028, 2, 10),
          due_date: Date.new(2028, 2, 29),
          settled_on: Date.new(2028, 2, 29)
        )
        create(
          :credit_card_invoice_settlement,
          credit_card:,
          payment_account: account,
          opening_date: Date.new(2028, 2, 11),
          closing_date: Date.new(2028, 3, 10),
          due_date: Date.new(2028, 3, 1),
          settled_on: Date.new(2028, 3, 1)
        )

        list_invoice_settlements(month: 2, year: 2028)

        expect(due_dates).to eq([ "2028-02-29" ])
      end

      it "does not return another user's invoice settlements" do
        create(:credit_card_invoice_settlement, credit_card:, payment_account: account, due_date: Date.new(2026, 8, 17))
        other_card = create(:credit_card, closing_day: 10, due_day: 17)
        create(:credit_card_invoice_settlement, credit_card: other_card, due_date: Date.new(2026, 8, 17))

        list_invoice_settlements(month: 8, year: 2026)

        expect(item_attributes).to contain_exactly(hash_including("credit_card_id" => credit_card.id))
      end

      it "orders by due_date, then credit_card_id" do
        later_card = create(:credit_card, user:, default_payment_account: account, closing_day: 10, due_day: 20)
        earlier = create(
          :credit_card_invoice_settlement,
          credit_card:,
          payment_account: account,
          due_date: Date.new(2026, 8, 10),
          settled_on: Date.new(2026, 8, 10)
        )
        later = create(
          :credit_card_invoice_settlement,
          credit_card: later_card,
          payment_account: account,
          opening_date: Date.new(2026, 7, 14),
          closing_date: Date.new(2026, 8, 13),
          due_date: Date.new(2026, 8, 20),
          settled_on: Date.new(2026, 8, 20)
        )
        same_day_other = create(
          :credit_card_invoice_settlement,
          credit_card: later_card,
          payment_account: account,
          opening_date: Date.new(2026, 6, 14),
          closing_date: Date.new(2026, 7, 13),
          due_date: Date.new(2026, 8, 10),
          settled_on: Date.new(2026, 8, 10)
        )

        list_invoice_settlements(month: 8, year: 2026)

        expected_ids = [ earlier, same_day_other, later ]
          .sort_by { |invoice| [ invoice.due_date, invoice.credit_card_id, invoice.id ] }
          .map(&:id)

        expect(item_attributes.map { |item| item.fetch("id") }).to eq(expected_ids)
      end

      it "returns an empty collection when there are no matching invoices" do
        create(
          :credit_card_invoice_settlement,
          credit_card:,
          payment_account: account,
          opening_date: Date.new(2026, 8, 11),
          closing_date: Date.new(2026, 9, 10),
          due_date: Date.new(2026, 9, 17),
          settled_on: Date.new(2026, 9, 17)
        )

        list_invoice_settlements(month: 8, year: 2026)

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["data"]).to eq([])
      end

      it "returns 422 when month is missing" do
        list_invoice_settlements(year: 2026)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "month")).to be_present
      end

      it "returns 422 when year is missing" do
        list_invoice_settlements(month: 8)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "year")).to be_present
      end

      it "returns 422 for an invalid month" do
        list_invoice_settlements(month: 13, year: 2026)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "month")).to be_present
      end

      it "returns 422 for month 0" do
        list_invoice_settlements(month: 0, year: 2026)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "month")).to be_present
      end

      it "returns 422 for year 0" do
        list_invoice_settlements(month: 8, year: 0)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "year")).to be_present
      end

      it "returns 422 for a year above 9999" do
        list_invoice_settlements(month: 8, year: 10_000)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "year")).to be_present
      end
    end

    context "when unauthenticated" do
      subject { list_invoice_settlements({ month: 8, year: 2026 }, {}) }

      it_behaves_like "an unauthorized API request"
    end
  end
end
