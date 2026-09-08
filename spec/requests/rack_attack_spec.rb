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

  def exceed_dedicated_throttle(http_method, path, params: {})
    10.times do
      public_send(http_method, path, params:, as: :json)
      expect(response).not_to have_http_status(:too_many_requests)
    end

    public_send(http_method, path, params:, as: :json)
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
end
