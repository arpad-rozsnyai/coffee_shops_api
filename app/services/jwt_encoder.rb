class JwtEncoder
  ACCESS = "access".freeze
  REFRESH = "refresh".freeze

  TTLS = {
    ACCESS => Auth::ACCESS_TOKEN_TTL,
    REFRESH => Auth::REFRESH_TOKEN_TTL
  }.freeze

  def initialize(user:, token_type:)
    @user = user
    @token_type = token_type.to_s
    raise ArgumentError, "Unknown token type: #{@token_type.inspect}" unless TTLS.key?(@token_type)
  end

  # Returns [token, expires_at] rather than a shared struct/type - the two mutations that call this
  # (login, refreshToken) each need one or both values inline, and nothing else in the app touches this.
  def call
    expires_at = Time.current + TTLS[token_type]
    payload = { sub: user.id, type: token_type, exp: expires_at.to_i }
    payload[:jti] = record_current_jti! if token_type == ACCESS
    token = JWT.encode(payload, Auth.jwt_secret, Auth::JWT_ALGORITHM)

    [ token, expires_at ]
  end

  private

  attr_reader :user, :token_type

  # Issuing a new access token immediately supersedes every access token issued before it -
  # JwtDecoder rejects any access token whose `jti` claim doesn't match the user's
  # current_access_token_jti, so only the most recently issued one is ever valid. An unconditional
  # overwrite (not an increment), so concurrent issuance can't lose an update the way a
  # read-modify-write counter could.
  def record_current_jti!
    jti = SecureRandom.uuid
    user.update_column(:current_access_token_jti, jti)
    jti
  end
end
