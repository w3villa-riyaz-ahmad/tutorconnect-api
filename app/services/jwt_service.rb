class JwtService
  SECRET_KEY = ENV.fetch("JWT_SECRET") { Rails.application.secret_key_base }
  ACCESS_TOKEN_EXPIRY = 24.hours
  REFRESH_TOKEN_EXPIRY = 7.days

  class << self
    # Encode a payload into a JWT access token
    def encode(user_id, token_type: :access)
      expiry = token_type == :refresh ? REFRESH_TOKEN_EXPIRY : ACCESS_TOKEN_EXPIRY

      payload = {
        user_id: user_id,
        type: token_type.to_s,
        exp: expiry.from_now.to_i,
        iat: Time.current.to_i,
        jti: SecureRandom.uuid # unique token ID to prevent replay
      }

      JWT.encode(payload, SECRET_KEY, "HS256")
    end

    # Decode and verify a JWT token
    def decode(token)
      decoded = JWT.decode(token, SECRET_KEY, true, {
        algorithm: "HS256",
        verify_expiration: true
      })
      HashWithIndifferentAccess.new(decoded.first)
    rescue JWT::ExpiredSignature
      nil
    rescue JWT::DecodeError
      nil
    end

    # Generate both access + refresh token pair
    def generate_tokens(user)
      refresh_token = encode(user.id, token_type: :refresh)
      user.update!(refresh_token: refresh_token)

      {
        token: encode(user.id, token_type: :access),
        refresh_token: refresh_token
      }
    end

    # Refresh: validate refresh token, issue new access token
    def refresh(refresh_token)
      payload = decode(refresh_token)
      return nil unless payload && payload[:type] == "refresh"

      user = User.find_by(id: payload[:user_id], refresh_token: refresh_token)
      return nil unless user

      {
        token: encode(user.id, token_type: :access),
        refresh_token: refresh_token # keep same refresh token
      }
    end

    # Invalidate refresh token on logout
    def invalidate(user)
      user.update!(refresh_token: nil)
    end
  end
end
