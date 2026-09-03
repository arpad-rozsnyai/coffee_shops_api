require "rails_helper"

RSpec.describe JwtDecoder do
  let(:user) { create(:user) }
  let(:access_token) { JwtEncoder.new(user: user, token_type: :access).call.first }
  let(:refresh_token) { JwtEncoder.new(user: user, token_type: :refresh).call.first }

  describe "#call" do
    it "returns the user for a valid access token when :access is expected" do
      expect(described_class.new(token: access_token, expected_type: :access).call).to eq(user)
    end

    it "returns the user for a valid refresh token when :refresh is expected" do
      expect(described_class.new(token: refresh_token, expected_type: :refresh).call).to eq(user)
    end

    it "raises for an access token when :refresh is expected" do
      expect { described_class.new(token: access_token, expected_type: :refresh).call }
        .to raise_error(JwtDecoder::InvalidTokenError)
    end

    it "raises for a refresh token when :access is expected" do
      expect { described_class.new(token: refresh_token, expected_type: :access).call }
        .to raise_error(JwtDecoder::InvalidTokenError)
    end

    it "raises for a garbage token" do
      expect { described_class.new(token: "not-a-jwt", expected_type: :access).call }
        .to raise_error(JwtDecoder::InvalidTokenError)
    end

    it "raises for a token signed with a different secret" do
      forged = JWT.encode({ sub: user.id, type: "access", exp: 1.hour.from_now.to_i }, "wrong-secret", Auth::JWT_ALGORITHM)

      expect { described_class.new(token: forged, expected_type: :access).call }
        .to raise_error(JwtDecoder::InvalidTokenError)
    end

    it "raises for a token whose user no longer exists" do
      token = JwtEncoder.new(user: user, token_type: :access).call.first
      user.destroy!

      expect { described_class.new(token: token, expected_type: :access).call }
        .to raise_error(JwtDecoder::InvalidTokenError)
    end

    it "raises for an access token superseded by a more recently issued one" do
      superseded_token, = JwtEncoder.new(user: user, token_type: :access).call
      JwtEncoder.new(user: user, token_type: :access).call

      expect { described_class.new(token: superseded_token, expected_type: :access).call }
        .to raise_error(JwtDecoder::InvalidTokenError)
    end

    it "accepts the most recently issued access token" do
      JwtEncoder.new(user: user, token_type: :access).call
      latest_token, = JwtEncoder.new(user: user, token_type: :access).call

      expect(described_class.new(token: latest_token, expected_type: :access).call).to eq(user)
    end

    it "does not apply the current_access_token_jti check to refresh tokens" do
      old_refresh_token, = JwtEncoder.new(user: user, token_type: :refresh).call
      JwtEncoder.new(user: user, token_type: :access).call # updates current_access_token_jti, but only for access

      expect(described_class.new(token: old_refresh_token, expected_type: :refresh).call).to eq(user)
    end
  end
end
