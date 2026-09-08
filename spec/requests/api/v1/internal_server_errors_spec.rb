require "rails_helper"

RSpec.describe "API::V1 internal server errors", type: :request do
  let(:user) { create(:user, :verified) }
  let(:headers) { auth_headers_for(user) }

  it "reports the exception and returns the exception message outside production" do
    allow(Account).to receive(:list).and_raise(StandardError, "boom")
    allow(Rails.error).to receive(:report)

    get "/api/v1/accounts", headers: headers

    expect(response).to have_http_status(:internal_server_error)
    expect(response.parsed_body["message"]).to eq("boom")
    expect(Rails.error).to have_received(:report).with(instance_of(StandardError), source: "api/v1")
  end

  it "hides the exception message in production" do
    allow(Account).to receive(:list).and_raise(StandardError, "boom")
    allow(Rails.error).to receive(:report)
    allow(Rails.env).to receive(:production?).and_return(true)

    get "/api/v1/accounts", headers: headers

    expect(response).to have_http_status(:internal_server_error)
    expect(response.parsed_body["message"]).to eq(I18n.t("user.errors.internal_server_error"))
  end
end
