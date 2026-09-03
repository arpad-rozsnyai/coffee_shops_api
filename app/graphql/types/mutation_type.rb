module Types
  class MutationType < Types::BaseObject
    # A fixed dummy hash, compared against on every login with an unrecognized email - so that path
    # spends the same bcrypt time as a recognized email with the wrong password. Without this,
    # `user.valid_password?` (bcrypt, deliberately slow) only ever runs when `user` is present,
    # making response time itself leak which emails are registered.
    DUMMY_PASSWORD_DIGEST = BCrypt::Password.create("dummy-password-for-timing-parity").freeze

    field :login, Types::AuthPayloadType, null: false do
      description "Authenticates a user by email and password, returning a short-lived access " \
        "token (#{Auth::ACCESS_TOKEN_TTL.inspect} TTL) and a longer-lived refresh token " \
        "(#{Auth::REFRESH_TOKEN_TTL.inspect} TTL). Immediately invalidates any access token issued " \
        "by a previous login or refreshToken call for this user"
      argument :email, String, required: true
      argument :password, String, required: true
    end

    field :refresh_token, Types::RefreshPayloadType, null: false do
      description "Exchanges a valid, unexpired refresh token for a new access token. Immediately " \
        "invalidates any access token issued by a previous login or refreshToken call for this user"
      argument :refresh_token, String, required: true
    end

    def login(email:, password:)
      user = User.find_for_authentication(email: email)
      raise GraphQL::ExecutionError, "Invalid email or password" unless valid_credentials?(user, password)

      access_token, access_token_expires_at = JwtEncoder.new(user: user, token_type: :access).call
      refresh_token, refresh_token_expires_at = JwtEncoder.new(user: user, token_type: :refresh).call

      {
        access_token: access_token,
        access_token_expires_at: access_token_expires_at,
        refresh_token: refresh_token,
        refresh_token_expires_at: refresh_token_expires_at
      }
    end

    def refresh_token(refresh_token:)
      user = JwtDecoder.new(token: refresh_token, expected_type: :refresh).call
      access_token, access_token_expires_at = JwtEncoder.new(user: user, token_type: :access).call

      { access_token: access_token, access_token_expires_at: access_token_expires_at }
    rescue JwtDecoder::InvalidTokenError => e
      raise GraphQL::ExecutionError, e.message
    end

    private

    def valid_credentials?(user, password)
      if user
        user.valid_password?(password)
      else
        BCrypt::Password.new(DUMMY_PASSWORD_DIGEST) == password
        false
      end
    end
  end
end
