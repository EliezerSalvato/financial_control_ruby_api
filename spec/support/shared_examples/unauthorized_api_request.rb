RSpec.shared_examples "an unauthorized API request" do
  it "does not authorize the request" do
    subject

    expect(response).to have_http_status(:unauthorized)
    expect(response.parsed_body["status"]).to eq("error")
    expect(response.parsed_body["message"]).to eq("Unauthorized")
  end
end
