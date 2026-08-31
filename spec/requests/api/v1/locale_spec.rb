require "rails_helper"

RSpec.describe "API locale", type: :request do
  describe "authenticated requests" do
    let(:user) { create(:user, :verified, first_name: "John", last_name: "Doe") }
    let(:headers) { auth_headers_for(user) }

    def update_profile(extra_headers = {})
      patch "/api/v1/user/profiles",
            params: { first_name: "Jane" },
            headers: headers.merge(extra_headers),
            as: :json
    end

    it "uses the locale from the user configs" do
      user.update!(configs: { "locale" => "pt-BR" })
      cookies[:locale] = "en"

      update_profile("Accept-Language" => "en")

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["message"]).to eq("Perfil atualizado com sucesso")
    end

    it "defaults to English when the user configs locale is not set" do
      cookies[:locale] = "pt-BR"

      update_profile("Accept-Language" => "pt-BR")

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["message"]).to eq("Profile updated successfully")
    end

    it "defaults to English when the user configs locale is not available" do
      user.update!(configs: { "locale" => "fr" })
      cookies[:locale] = "pt-BR"

      update_profile

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["message"]).to eq("Profile updated successfully")
    end
  end

  describe "unauthenticated requests" do
    def authenticate(extra_headers = {})
      post "/api/v1/user/authentications",
           params: { email: "unknown@example.com", password: "wrong-password" },
           headers: extra_headers,
           as: :json
    end

    it "uses the locale cookie" do
      cookies[:locale] = "pt-BR"

      authenticate

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("details", "base")).to eq([ "E-mail ou senha inválidos" ])
    end

    it "uses Accept-Language when the locale cookie is missing" do
      authenticate("Accept-Language" => "pt-BR")

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("details", "base")).to eq([ "E-mail ou senha inválidos" ])
    end

    it "defaults to English when the locale cookie and Accept-Language are missing" do
      authenticate

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("details", "base")).to eq([ "Email or password is invalid" ])
    end

    it "uses the locale cookie on unauthorized protected endpoints" do
      cookies[:locale] = "pt-BR"

      patch "/api/v1/user/profiles", params: { first_name: "Jane" }, as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body["message"]).to eq("Não autorizado")
    end
  end
end
