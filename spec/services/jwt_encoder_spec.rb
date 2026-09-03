require "rails_helper"

RSpec.describe JwtEncoder do
  let(:user) { create(:user) }

  describe "#call" do
    it "returns a token and its expiry" do
      token, expires_at = described_class.new(user: user, token_type: :access).call

      expect(token).to be_a(String)
      expect(expires_at).to be_within(1.second).of(Time.current + Auth::ACCESS_TOKEN_TTL)
    end

    it "encodes an access token that JwtDecoder accepts as :access" do
      token, = described_class.new(user: user, token_type: :access).call

      expect(JwtDecoder.new(token: token, expected_type: :access).call).to eq(user)
    end

    it "encodes a refresh token that JwtDecoder accepts as :refresh" do
      token, = described_class.new(user: user, token_type: :refresh).call

      expect(JwtDecoder.new(token: token, expected_type: :refresh).call).to eq(user)
    end

    it "expires an access token after Auth::ACCESS_TOKEN_TTL, not Auth::REFRESH_TOKEN_TTL" do
      token, = described_class.new(user: user, token_type: :access).call

      travel_to(Time.current + Auth::ACCESS_TOKEN_TTL + 1.second) do
        expect { JwtDecoder.new(token: token, expected_type: :access).call }
          .to raise_error(JwtDecoder::InvalidTokenError)
      end
    end

    it "expires a refresh token after Auth::REFRESH_TOKEN_TTL" do
      token, = described_class.new(user: user, token_type: :refresh).call

      travel_to(Time.current + Auth::REFRESH_TOKEN_TTL + 1.second) do
        expect { JwtDecoder.new(token: token, expected_type: :refresh).call }
          .to raise_error(JwtDecoder::InvalidTokenError)
      end
    end

    it "records the issued jti as the user's current_access_token_jti when issuing an access token" do
      token, = described_class.new(user: user, token_type: :access).call
      decoded_jti = JWT.decode(token, Auth.jwt_secret, true, algorithm: Auth::JWT_ALGORITHM).first["jti"]

      expect(user.reload.current_access_token_jti).to eq(decoded_jti)
    end

    it "does not touch current_access_token_jti when issuing a refresh token" do
      expect { described_class.new(user: user, token_type: :refresh).call }
        .not_to change { user.reload.current_access_token_jti }
    end

    it "invalidates a previously issued access token once a new one is issued for the same user" do
      old_token, = described_class.new(user: user, token_type: :access).call
      described_class.new(user: user, token_type: :access).call

      expect { JwtDecoder.new(token: old_token, expected_type: :access).call }
        .to raise_error(JwtDecoder::InvalidTokenError)
    end
  end

  describe "#initialize" do
    it "raises for an unknown token type" do
      expect { described_class.new(user: user, token_type: :bogus) }.to raise_error(ArgumentError)
    end
  end
end
