class Rack::Attack
  GENERAL_REQUEST_LIMIT = 300
  GENERAL_REQUEST_PERIOD = 5.minutes
  AUTH_ENDPOINT_LIMIT = 10
  AUTH_ENDPOINT_PERIOD = 1.minute

  module Discriminator
    module_function

    def healthcheck?(req)
      req.path == "/up" || req.path == "/cable"
    end

    def hashed(value)
      return if value.blank?

      Digest::SHA256.hexdigest(value.to_s)
    end

    def hashed_bearer_token(req)
      hashed(bearer_token(req))
    end

    def user_id(req)
      token = bearer_token(req)
      return if token.blank?

      User::Record.signed_id_verifier.verified(
        token,
        purpose: User::Record.combine_signed_id_purposes(:session_token)
      )
    end

    def hashed_email(req)
      hashed(param(req, "email").to_s.strip.downcase.presence)
    end

    def hashed_param(req, key)
      hashed(param(req, key))
    end

    def hashed_cookie(req, name)
      hashed(req.cookies[name])
    end

    def bearer_token(req)
      authorization = req.get_header("HTTP_AUTHORIZATION")
      return if authorization.blank?

      scheme, token = authorization.split(" ", 2)
      token.presence if scheme&.casecmp("bearer")&.zero?
    end

    def param(req, key)
      params_hash(req)[key]
    end

    def params_hash(req)
      parsed = json_params(req)
      return parsed if parsed.any?

      req.params
    end

    def json_params(req)
      return {} unless req.media_type == "application/json"

      raw = req.body.read
      req.body.rewind
      return {} if raw.blank?

      parsed = JSON.parse(raw)
      parsed.is_a?(Hash) ? parsed : {}
    rescue JSON::ParserError
      req.body.rewind if req.body.respond_to?(:rewind)
      {}
    end
  end

  throttle("requests/ip", limit: ->(_req) { GENERAL_REQUEST_LIMIT }, period: GENERAL_REQUEST_PERIOD) do |req|
    req.ip unless Discriminator.healthcheck?(req)
  end

  throttle("requests/token", limit: ->(_req) { GENERAL_REQUEST_LIMIT }, period: GENERAL_REQUEST_PERIOD) do |req|
    Discriminator.hashed_bearer_token(req) unless Discriminator.healthcheck?(req)
  end

  throttle("requests/user", limit: ->(_req) { GENERAL_REQUEST_LIMIT }, period: GENERAL_REQUEST_PERIOD) do |req|
    Discriminator.user_id(req) unless Discriminator.healthcheck?(req)
  end

  throttle("login/ip", limit: AUTH_ENDPOINT_LIMIT, period: AUTH_ENDPOINT_PERIOD) do |req|
    req.ip if req.post? && req.path == "/api/v1/user/authentications"
  end

  throttle("login/email", limit: AUTH_ENDPOINT_LIMIT, period: AUTH_ENDPOINT_PERIOD) do |req|
    Discriminator.hashed_email(req) if req.post? && req.path == "/api/v1/user/authentications"
  end

  throttle("registrations/ip", limit: AUTH_ENDPOINT_LIMIT, period: AUTH_ENDPOINT_PERIOD) do |req|
    req.ip if req.post? && req.path == "/api/v1/user/registrations"
  end

  throttle("registrations/email", limit: AUTH_ENDPOINT_LIMIT, period: AUTH_ENDPOINT_PERIOD) do |req|
    Discriminator.hashed_email(req) if req.post? && req.path == "/api/v1/user/registrations"
  end

  throttle("password_resets/ip", limit: AUTH_ENDPOINT_LIMIT, period: AUTH_ENDPOINT_PERIOD) do |req|
    req.ip if req.path == "/api/v1/user/password/resets" && (req.post? || req.patch? || req.put?)
  end

  throttle("password_resets/email", limit: AUTH_ENDPOINT_LIMIT, period: AUTH_ENDPOINT_PERIOD) do |req|
    Discriminator.hashed_email(req) if req.post? && req.path == "/api/v1/user/password/resets"
  end

  throttle("password_resets/token", limit: AUTH_ENDPOINT_LIMIT, period: AUTH_ENDPOINT_PERIOD) do |req|
    Discriminator.hashed_param(req, "token") if req.path == "/api/v1/user/password/resets" && (req.patch? || req.put?)
  end

  throttle("session_refreshes/ip", limit: AUTH_ENDPOINT_LIMIT, period: AUTH_ENDPOINT_PERIOD) do |req|
    req.ip if req.patch? && req.path == "/api/v1/user/session/refreshes"
  end

  throttle("session_refreshes/token", limit: AUTH_ENDPOINT_LIMIT, period: AUTH_ENDPOINT_PERIOD) do |req|
    Discriminator.hashed_cookie(req, "refresh_token") if req.patch? && req.path == "/api/v1/user/session/refreshes"
  end
end
