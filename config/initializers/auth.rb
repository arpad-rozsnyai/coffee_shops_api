module Auth
  JWT_ALGORITHM = "HS256"

  ACCESS_TOKEN_TTL = 3.minutes
  REFRESH_TOKEN_TTL = 2.hours

  def self.jwt_secret
    ENV.fetch("JWT_SECRET", Rails.application.secret_key_base)
  end
end
