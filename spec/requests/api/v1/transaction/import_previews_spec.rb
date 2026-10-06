require "rails_helper"

RSpec.describe "API::V1::Transaction::Import::Previews", type: :request do
  include ActiveJob::TestHelper

  let(:user) { create(:user, :verified) }
  let(:headers) { auth_headers_for(user) }
  let(:account) { create(:account, user:) }
  let(:file) { fixture_file_upload("transaction_imports/statement.csv", "text/csv") }
  let(:params) { { file:, kind: "expense", payment_method: "pix", account_id: account.id } }

  def create_preview(request_params = params, request_headers = headers)
    post "/api/v1/transactions/imports/previews", params: request_params, headers: request_headers
  end

  def csv_upload(content, filename: "statement.csv")
    Rack::Test::UploadedFile.new(StringIO.new(content), "text/csv", original_filename: filename)
  end

  describe "POST /api/v1/transactions/imports/previews" do
    context "when the request is valid" do
      it "enqueues one job per row and returns the import id" do
        expect { create_preview }.to have_enqueued_job(Transaction::Import::PreviewRowJob).exactly(4).times

        expect(response).to have_http_status(:accepted)
        expect(response.parsed_body["data"]).to include("total_rows" => 4)
        expect(UUID.valid?(response.parsed_body.dig("data", "import_id"))).to be(true)
      end

      it "numbers identical lines by occurrence and shares the form defaults" do
        create_preview

        jobs = enqueued_jobs.map { |job| ActiveJob::Arguments.deserialize(job["arguments"]).first }

        expect(jobs.map { |job| [ job[:row], job[:occurrence] ] }).to eq([ [ 1, 1 ], [ 2, 1 ], [ 3, 1 ], [ 4, 2 ] ])
        expect(jobs.first).to include(
          user_id: user.id,
          defaults: { kind: "expense", payment_method: "pix", account_id: account.id, credit_card_id: nil, limit_consumption_type: nil, installments_count: nil }
        )
        expect(jobs.first[:data]).to include("description" => "Ifd*Burger King", "source_column" => "title")
      end

      it "accepts semicolon separated files with BOM and skips blank lines" do
        expect {
          create_preview(params.merge(file: fixture_file_upload("transaction_imports/semicolon_bom.csv", "text/csv")))
        }.to have_enqueued_job(Transaction::Import::PreviewRowJob).exactly(2).times

        expect(response).to have_http_status(:accepted)
        expect(response.parsed_body.dig("data", "total_rows")).to eq(2)
      end

      it "accepts latin-1 encoded files" do
        content = "date,description,amount\n2026-10-01,Caf\xE9,5.00\n".b

        create_preview(params.merge(file: csv_upload(content)))

        expect(response).to have_http_status(:accepted)
      end

      it "accepts a credit card" do
        card = create(:credit_card, user:)

        expect {
          create_preview(file:, kind: "expense", payment_method: "credit_card", credit_card_id: card.id, limit_consumption_type: "upfront", installments_count: 3)
        }.to have_enqueued_job(Transaction::Import::PreviewRowJob).with(hash_including(
          defaults: {
            kind: "expense", payment_method: "credit_card", account_id: nil, credit_card_id: card.id,
            limit_consumption_type: "upfront", installments_count: 3
          }
        )).exactly(4).times
      end

      it "rejects an invalid installments count" do
        expect { create_preview(params.merge(installments_count: "1")) }.not_to have_enqueued_job

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "installments_count")).to be_present
      end
    end

    context "when the file is invalid" do
      it "rejects a missing file" do
        expect { create_preview(params.except(:file)) }.not_to have_enqueued_job

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "file")).to be_present
      end

      it "rejects a file that is not a CSV" do
        create_preview(params.merge(file: csv_upload("date,description,amount\n", filename: "statement.txt")))

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "file")).to eq([ "must be a CSV file" ])
      end

      it "rejects files larger than 1 MB" do
        create_preview(params.merge(file: csv_upload("date,description,amount\n" + ("2026-10-01,Coffee,5.00\n" * 50_000))))

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "file")).to eq([ "must be at most 1 MB" ])
      end

      it "rejects more than 1000 rows" do
        rows = Array.new(1001) { |index| "2026-10-01,Coffee #{index},5.00" }

        expect { create_preview(params.merge(file: csv_upload("date,description,amount\n#{rows.join("\n")}\n"))) }
          .not_to have_enqueued_job

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "file")).to eq([ "must have at most 1000 rows" ])
      end

      it "accepts exactly 1000 rows" do
        rows = Array.new(1000) { |index| "2026-10-01,Coffee #{index},5.00" }

        create_preview(params.merge(file: csv_upload("date,description,amount\n#{rows.join("\n")}\n")))

        expect(response).to have_http_status(:accepted)
      end

      it "rejects missing required columns" do
        create_preview(params.merge(file: fixture_file_upload("transaction_imports/missing_columns.csv", "text/csv")))

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "file")).to eq([ "is missing required columns: amount or value" ])
      end

      it "rejects malformed CSV" do
        create_preview(params.merge(file: csv_upload("date,description,amount\n2026-10-01,\"Coffee,5.00\n")))

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "file")).to eq([ "must be a CSV file" ])
      end
    end

    context "when the form defaults are invalid" do
      it "rejects an unknown kind" do
        create_preview(params.merge(kind: "gift"))

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "kind")).to be_present
      end

      it "rejects transfers" do
        create_preview(params.merge(kind: "transfer_between_accounts"))

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "kind")).to be_present
      end

      it "rejects a payment method that does not match the kind" do
        create_preview(params.merge(kind: "income", payment_method: "credit_card"))

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "payment_method")).to eq([ "is not allowed for this kind" ])
      end

      it "requires an account for account based payment methods" do
        create_preview(params.except(:account_id))

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "account_id")).to be_present
      end

      it "rejects another user's account" do
        create_preview(params.merge(account_id: create(:account).id))

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "account_id")).to eq([ "was not found" ])
      end

      it "rejects an inactive account" do
        create_preview(params.merge(account_id: create(:account, :inactive, user:).id))

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "account_id")).to eq([ "is inactive" ])
      end

      it "requires a credit card for credit card payments" do
        create_preview(file:, kind: "expense", payment_method: "credit_card")

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "credit_card_id")).to be_present
      end

      it "rejects another user's credit card" do
        create_preview(file:, kind: "expense", payment_method: "credit_card", credit_card_id: create(:credit_card).id)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "credit_card_id")).to eq([ "was not found" ])
      end

      it "rejects an inactive credit card" do
        card = create(:credit_card, :inactive, user:)

        create_preview(file:, kind: "expense", payment_method: "credit_card", credit_card_id: card.id)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("details", "credit_card_id")).to eq([ "is inactive" ])
      end
    end

    context "when unauthenticated" do
      subject { create_preview(params, {}) }

      it_behaves_like "an unauthorized API request"
    end
  end
end
