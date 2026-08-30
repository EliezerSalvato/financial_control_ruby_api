require "rails_helper"

RSpec.describe "API::V1::Settlements", type: :request do
  include ActiveJob::TestHelper

  let(:user) { create(:user, :verified) }
  let(:headers) { auth_headers_for(user) }

  describe "POST /api/v1/settlements/processing" do
    def process_settlements(params, request_headers = headers)
      post "/api/v1/settlements/processing", params: params, headers: request_headers, as: :json
    end

    context "when authenticated" do
      it "enqueues ProcessJob for the current user and does not settle in the request" do
        account = create(:account, :bank_account, user:, current_balance: 1000)
        create(:transaction, user:, account:, value: 100, starts_on: Date.new(2026, 8, 11))

        expect {
          process_settlements(settlement: { month: 8, year: 2026, reference_date: "2026-08-28" })
        }.to have_enqueued_job(Settlement::ProcessJob).with(
          user_id: user.id,
          month: 8,
          year: 2026,
          reference_date: "2026-08-28"
        )

        expect(response).to have_http_status(:accepted)
        expect(response.parsed_body["message"]).to eq("Settlement processing has been queued")
        expect(account.reload.current_balance).to eq(BigDecimal("1000"))
        expect(Transaction::Settlement::Record.count).to eq(0)
      end

      it "does not enqueue a job for another user" do
        other_user = create(:user, :verified)

        process_settlements(settlement: { month: 8, year: 2026, reference_date: "2026-08-28" })

        expect(Settlement::ProcessJob).to have_been_enqueued.with(hash_including(user_id: user.id))
        expect(Settlement::ProcessJob).not_to have_been_enqueued.with(hash_including(user_id: other_user.id))
      end

      it "returns 400 when the settlement param is missing" do
        process_settlements({})

        expect(response).to have_http_status(:bad_request)
        expect(Settlement::ProcessJob).not_to have_been_enqueued
      end

      it "returns the queued message in Portuguese when Accept-Language is pt-BR" do
        process_settlements(
          { settlement: { month: 8, year: 2026, reference_date: "2026-08-28" } },
          headers.merge("Accept-Language" => "pt-BR")
        )

        expect(response).to have_http_status(:accepted)
        expect(response.parsed_body["message"]).to eq("Efetivações enfileiradas para processamento")
      end
    end

    context "when unauthenticated" do
      subject { process_settlements({ settlement: { month: 8, year: 2026, reference_date: "2026-08-28" } }, {}) }

      it_behaves_like "an unauthorized API request"
    end
  end
end
