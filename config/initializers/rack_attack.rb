class Rack::Attack
  throttle("requests/ip", limit: 300, period: 5.minutes) do |req|
    req.ip unless req.path == "/up"
  end

  throttle("login/ip", limit: 10, period: 1.minute) do |req|
    req.ip if req.post? && req.path == "/api/v1/session"
  end
end
