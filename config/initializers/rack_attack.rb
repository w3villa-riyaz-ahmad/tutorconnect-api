class Rack::Attack
  # Throttle login attempts by IP — max 5 per minute
  throttle("login/ip", limit: 5, period: 60.seconds) do |req|
    req.ip if req.path == "/api/auth/login" && req.post?
  end

  # Throttle login attempts by email — max 5 per minute
  throttle("login/email", limit: 5, period: 60.seconds) do |req|
    if req.path == "/api/auth/login" && req.post?
      begin
        JSON.parse(req.body.read)["email"]&.downcase&.strip
      rescue
        nil
      ensure
        req.body.rewind
      end
    end
  end

  # Throttle signup by IP — max 3 per minute
  throttle("signup/ip", limit: 3, period: 60.seconds) do |req|
    req.ip if req.path == "/api/auth/signup" && req.post?
  end

  # Custom throttle response
  self.throttled_responder = lambda do |_request|
    [
      429,
      { "Content-Type" => "application/json" },
      [{ error: "Too many requests. Please try again later." }.to_json]
    ]
  end
end
