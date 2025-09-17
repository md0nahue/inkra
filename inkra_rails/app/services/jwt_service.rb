class JwtService
  # Access token expires in 1 hour
  ACCESS_TOKEN_EXPIRATION = 1.hour
  # Refresh token expires in 30 days
  REFRESH_TOKEN_EXPIRATION = 30.days

  class << self
    def encode_access_token(user_id)
      payload = {
        user_id: user_id,
        type: 'access'
      }
      JWT.encode(payload, secret_key, 'HS256')
    end

    def encode_refresh_token(user_id)
      payload = {
        user_id: user_id,
        type: 'refresh'
      }
      JWT.encode(payload, secret_key, 'HS256')
    end

    def decode_token(token)
      decoded = JWT.decode(token, secret_key, true, { algorithm: 'HS256' })
      decoded[0]
    rescue JWT::ExpiredSignature
      raise StandardError, 'Token has expired'
    rescue JWT::DecodeError
      raise StandardError, 'Invalid token'
    end

    def generate_token_pair(user_id)
      {
        access_token: encode_access_token(user_id),
        refresh_token: encode_refresh_token(user_id)
      }
    end

    private

    def secret_key
      Rails.application.credentials.secret_key_base
    end
  end
end