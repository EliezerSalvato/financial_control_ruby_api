require "rails_helper"

RSpec.describe "Rack::Attack", type: :request do
  around do |example|
    original_store = Rack::Attack.cache.store
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
    Rack::Attack.reset!
    example.run
  ensure
    Rack::Attack.reset!
    Rack::Attack.cache.store = original_store
  end

  def stub_public_auth_actions
    failure = Solid::Failure(:throttled_probe)

    allow(User).to receive_messages(
      authenticate: failure,
      register: failure,
      send_reset_password_instructions: failure,
      reset_password: failure,
      refresh_session: failure
    )
  end

  def exceed_dedicated_throttle(http_method, path, params: {}, headers: {}, env: {})
    Rack::Attack::AUTH_ENDPOINT_LIMIT.times do
      public_send(http_method, path, params:, headers:, env:, as: :json)
      expect(response).not_to have_http_status(:too_many_requests)
    end

    public_send(http_method, path, params:, headers:, env:, as: :json)
    expect(response).to have_http_status(:too_many_requests)
  end

  def exceed_from_rotating_ips(http_method, path, params: {}, headers: {})
    Rack::Attack::AUTH_ENDPOINT_LIMIT.times do |index|
      public_send(
        http_method,
        path,
        params:,
        headers:,
        env: { "REMOTE_ADDR" => "10.0.0.#{index + 1}" },
        as: :json
      )
      expect(response).not_to have_http_status(:too_many_requests)
    end

    public_send(
      http_method,
      path,
      params:,
      headers:,
      env: { "REMOTE_ADDR" => "10.0.0.250" },
      as: :json
    )
    expect(response).to have_http_status(:too_many_requests)
  end

  before { stub_public_auth_actions }

  it "throttles the real login endpoint after 10 POSTs per IP per minute" do
    exceed_dedicated_throttle(:post, "/api/v1/user/authentications", params: { email: "a@example.com", password: "x" })
  end

  it "does not apply the login throttle to the legacy /api/v1/session path" do
    11.times { post "/api/v1/session", as: :json }

    expect(response).not_to have_http_status(:too_many_requests)
  end

  it "throttles registrations, password resets, and session refreshes per IP" do
    exceed_dedicated_throttle(
      :post,
      "/api/v1/user/registrations",
      params: { first_name: "A", last_name: "B", email: "a@example.com", password: "password123", password_confirmation: "password123" }
    )

    Rack::Attack.reset!

    exceed_dedicated_throttle(:post, "/api/v1/user/password/resets", params: { email: "a@example.com" })

    Rack::Attack.reset!

    exceed_dedicated_throttle(:patch, "/api/v1/user/password/resets", params: { token: "t", password: "password123", password_confirmation: "password123" })

    Rack::Attack.reset!

    exceed_dedicated_throttle(:patch, "/api/v1/user/session/refreshes")
  end

  it "throttles login by email across different IPs" do
    exceed_from_rotating_ips(:post, "/api/v1/user/authentications", params: { email: "a@example.com", password: "x" })
  end

  it "does not share the login email throttle across different emails" do
    Rack::Attack::AUTH_ENDPOINT_LIMIT.times do |index|
      post "/api/v1/user/authentications",
           params: { email: "a@example.com", password: "x" },
           env: { "REMOTE_ADDR" => "10.1.0.#{index + 1}" },
           as: :json
    end

    post "/api/v1/user/authentications",
         params: { email: "b@example.com", password: "x" },
         env: { "REMOTE_ADDR" => "10.1.0.250" },
         as: :json

    expect(response).not_to have_http_status(:too_many_requests)
  end

  it "throttles registrations and password resets by email or token across different IPs" do
    exceed_from_rotating_ips(
      :post,
      "/api/v1/user/registrations",
      params: { first_name: "A", last_name: "B", email: "a@example.com", password: "password123", password_confirmation: "password123" }
    )

    Rack::Attack.reset!

    exceed_from_rotating_ips(:post, "/api/v1/user/password/resets", params: { email: "a@example.com" })

    Rack::Attack.reset!

    exceed_from_rotating_ips(
      :patch,
      "/api/v1/user/password/resets",
      params: { token: "t", password: "password123", password_confirmation: "password123" }
    )
  end

  it "throttles session refreshes by refresh token across different IPs" do
    cookies[:refresh_token] = "refresh-token-probe"

    exceed_from_rotating_ips(:patch, "/api/v1/user/session/refreshes")
  end

  it "throttles authenticated requests by bearer token across different IPs" do
    stub_const("Rack::Attack::GENERAL_REQUEST_LIMIT", Rack::Attack::AUTH_ENDPOINT_LIMIT)
    user = create(:user, :verified)

    exceed_from_rotating_ips(:get, "/api/v1/categories", headers: auth_headers_for(user))
  end

  it "throttles authenticated requests by user across different session tokens" do
    stub_const("Rack::Attack::GENERAL_REQUEST_LIMIT", Rack::Attack::AUTH_ENDPOINT_LIMIT)
    user = create(:user, :verified)
    first_headers = auth_headers_for(user, expires_in: 1.hour)
    second_headers = auth_headers_for(user, expires_in: 2.hours)

    Rack::Attack::AUTH_ENDPOINT_LIMIT.times do |index|
      get "/api/v1/categories",
          headers: first_headers,
          env: { "REMOTE_ADDR" => "10.2.0.#{index + 1}" },
          as: :json
      expect(response).not_to have_http_status(:too_many_requests)
    end

    get "/api/v1/categories",
        headers: second_headers,
        env: { "REMOTE_ADDR" => "10.2.0.250" },
        as: :json

    expect(response).to have_http_status(:too_many_requests)
  end
end
