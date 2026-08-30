allowed_origins = [
  *ENV.fetch("CORS_ORIGINS", "").split(",").map(&:strip),
  *Array(Rails.application.credentials.dig(:cors, :origins))
].compact_blank.uniq

Rails.application.config.action_cable.allowed_request_origins = allowed_origins if allowed_origins.any?

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins(*allowed_origins)

    resource "*",
      headers: :any,
      methods: %i[get post put patch delete options head],
      credentials: true
  end
end
