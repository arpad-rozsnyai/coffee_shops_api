class JwtDecoder
  class InvalidTokenError < StandardError
  end

  def initialize(token:, expected_type:)
    @token = token
    @expected_type = expected_type.to_s
  end

  def call
    payload = decode_payload
    unless payload["type"] == expected_type
      raise InvalidTokenError, "Expected a #{expected_type} token"
    end

    user = User.find(payload["sub"])
    if expected_type == JwtEncoder::ACCESS && payload["jti"] != user.current_access_token_jti
      raise InvalidTokenError, "Access token has been superseded by a newer one"
    end

    user
  rescue JWT::DecodeError, ActiveRecord::RecordNotFound => e
    raise InvalidTokenError, "Invalid or expired token: #{e.message}"
  end

  private

  attr_reader :token, :expected_type

  def decode_payload
    JWT.decode(token, Auth.jwt_secret, true, algorithm: Auth::JWT_ALGORITHM).first
  end
end
