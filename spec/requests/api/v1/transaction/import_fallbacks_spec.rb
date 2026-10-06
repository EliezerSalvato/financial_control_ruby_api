require "rails_helper"

RSpec.describe "API import facade fallback branches", type: :request do
  let(:user) { create(:user, :verified) }
  let(:headers) { auth_headers_for(user) }
  let(:id) { UUID.generate }
  let(:unexpected) { Solid::Failure(:unexpected) }
  let(:csv) { fixture_file_upload("transaction_imports/statement.csv", "text/csv") }

  def input_failure(process_class)
    input = process_class::Input.new
    input.errors.add(:base, :invalid)
    Solid::Failure(:invalid_input, input:)
  end

  describe "import rules" do
    it "returns bad request when listing fails with invalid_filters" do
      allow(Transaction).to receive(:list_import_rules).and_return(Solid::Failure(:invalid_filters))

      get "/api/v1/transactions/import_rules", headers: headers

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body["message"]).to eq(I18n.t("transaction.import_rule.errors.invalid_filters"))
    end

    it "returns the input errors when listing fails with them" do
      allow(Transaction).to receive(:list_import_rules).and_return(input_failure(Core::Transaction::Import::Rule::Listing))

      get "/api/v1/transactions/import_rules", headers: headers

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "returns bad request when listing fails unexpectedly" do
      allow(Transaction).to receive(:list_import_rules).and_return(unexpected)

      get "/api/v1/transactions/import_rules", headers: headers

      expect(response).to have_http_status(:bad_request)
    end

    it "returns not found when showing fails unexpectedly" do
      allow(Transaction).to receive(:find_import_rule).and_return(unexpected)

      get "/api/v1/transactions/import_rules/#{id}", headers: headers

      expect(response).to have_http_status(:not_found)
    end

    it "returns unprocessable content when creating fails unexpectedly" do
      allow(Transaction).to receive(:create_import_rule).and_return(unexpected)

      post "/api/v1/transactions/import_rules", params: { import_rule: { name: "x", pattern: "x" } }, headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["message"]).to eq(I18n.t("transaction.import_rule.creation.failure"))
    end

    it "returns unprocessable content when updating fails unexpectedly" do
      allow(Transaction).to receive(:update_import_rule).and_return(unexpected)

      patch "/api/v1/transactions/import_rules/#{id}", params: { import_rule: { name: "x" } }, headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["message"]).to eq(I18n.t("transaction.import_rule.update.failure"))
    end

    it "returns the input errors when deleting fails with them" do
      allow(Transaction).to receive(:destroy_import_rule).and_return(input_failure(Core::Transaction::Import::Rule::Deletion))

      delete "/api/v1/transactions/import_rules/#{id}", headers: headers

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "returns unprocessable content when deleting fails unexpectedly" do
      allow(Transaction).to receive(:destroy_import_rule).and_return(unexpected)

      delete "/api/v1/transactions/import_rules/#{id}", headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["message"]).to eq(I18n.t("transaction.import_rule.deletion.failure"))
    end
  end

  describe "imports" do
    it "returns unprocessable content when the preview fails unexpectedly" do
      allow(Transaction).to receive(:preview_import).and_return(unexpected)

      post "/api/v1/transactions/imports/previews", params: { file: csv, kind: "expense" }, headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["message"]).to eq(I18n.t("transaction.import.failure"))
    end

    it "returns unprocessable content when the confirmation fails unexpectedly" do
      allow(Transaction).to receive(:confirm_import).and_return(unexpected)

      post "/api/v1/transactions/imports", params: { import_id: id, rows: [ { row: 1 } ] }, headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["message"]).to eq(I18n.t("transaction.import.failure"))
    end
  end
end
