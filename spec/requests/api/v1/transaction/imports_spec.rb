require "rails_helper"

RSpec.describe "API::V1::Transaction::Imports", type: :request do
  include ActiveJob::TestHelper

  let(:user) { create(:user, :verified) }
  let(:headers) { auth_headers_for(user) }
  let(:import_id) { SecureRandom.uuid_v7 }
  let(:row) do
    {
      row: 1, create: true, source_key: "2026-10-01|Coffee|5.00", date: "2026-10-01", description: "Coffee",
      amount: "5.00", kind: "expense", payment_method: "pix", account_id: SecureRandom.uuid_v7,
      recurrence_type: "one_time", category_name: "Food", tag_ids: [], tag_names: [ "daily" ]
    }
  end

  def create_import(params, request_headers = headers)
    post "/api/v1/transactions/imports", params:, headers: request_headers, as: :json
  end

  describe "POST /api/v1/transactions/imports" do
    it "enqueues one job per row" do
      rows = [ row, row.merge(row: 2, create: false) ]

      expect { create_import(import_id:, rows:) }.to have_enqueued_job(Transaction::Import::PersistRowJob).exactly(2).times

      expect(response).to have_http_status(:accepted)
      expect(response.parsed_body["data"]).to eq("import_id" => import_id, "total_rows" => 2)
    end

    it "passes the permitted row attributes to the job" do
      create_import(import_id:, rows: [ row.merge(unknown: "x") ])

      expect(Transaction::Import::PersistRowJob).to have_been_enqueued.with(hash_including(user_id: user.id, import_id:, row:))
    end

    it "returns 400 for empty rows" do
      expect { create_import(import_id:, rows: []) }.not_to have_enqueued_job

      expect(response).to have_http_status(:bad_request)
    end

    it "rejects more than 1000 rows" do
      expect { create_import(import_id:, rows: Array.new(1001) { row }) }.not_to have_enqueued_job

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("details", "rows")).to eq([ "must have at most 1000 rows" ])
    end

    it "rejects rows that are not objects" do
      create_import(import_id:, rows: [ "x" ])

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "rejects an invalid import id" do
      create_import(import_id: "abc", rows: [ row ])

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("details", "import_id")).to be_present
    end

    it "returns 400 without rows" do
      create_import(import_id:)

      expect(response).to have_http_status(:bad_request)
    end

    context "when unauthenticated" do
      subject { create_import({ import_id:, rows: [ row ] }, {}) }

      it_behaves_like "an unauthorized API request"
    end
  end
end
