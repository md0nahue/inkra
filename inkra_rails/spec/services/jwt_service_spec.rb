require 'rails_helper'

RSpec.describe JwtService, type: :service do
  let(:user_id) { 1 }
  let(:secret_key) { Rails.application.credentials.secret_key_base }

  describe '.encode_access_token' do
    let(:token) { described_class.encode_access_token(user_id) }

    it 'generates a valid JWT token' do
      expect(token).to be_a(String)
      expect(token.split('.').length).to eq(3) # JWT has 3 parts
    end

    it 'includes correct payload data' do
      decoded = JWT.decode(token, secret_key, true, { algorithm: 'HS256' })
      payload = decoded[0]

      expect(payload['user_id']).to eq(user_id)
      expect(payload['type']).to eq('access')
      expect(payload['exp']).to be > Time.current.to_i
      expect(payload['exp']).to be <= 1.hour.from_now.to_i
    end

    it 'sets correct expiration time' do
      decoded = JWT.decode(token, secret_key, true, { algorithm: 'HS256' })
      payload = decoded[0]
      
      # Allow some leeway for test execution time (within 5 seconds)
      expected_exp = JwtService::ACCESS_TOKEN_EXPIRATION.from_now.to_i
      expect(payload['exp']).to be_within(5).of(expected_exp)
    end
  end

  describe '.encode_refresh_token' do
    let(:token) { described_class.encode_refresh_token(user_id) }

    it 'generates a valid JWT token' do
      expect(token).to be_a(String)
      expect(token.split('.').length).to eq(3)
    end

    it 'includes correct payload data' do
      decoded = JWT.decode(token, secret_key, true, { algorithm: 'HS256' })
      payload = decoded[0]

      expect(payload['user_id']).to eq(user_id)
      expect(payload['type']).to eq('refresh')
      expect(payload['exp']).to be > Time.current.to_i
      expect(payload['exp']).to be <= 30.days.from_now.to_i
    end

    it 'sets correct expiration time' do
      decoded = JWT.decode(token, secret_key, true, { algorithm: 'HS256' })
      payload = decoded[0]
      
      expected_exp = JwtService::REFRESH_TOKEN_EXPIRATION.from_now.to_i
      expect(payload['exp']).to be_within(5).of(expected_exp)
    end
  end

  describe '.decode_token' do
    context 'with valid access token' do
      let(:token) { described_class.encode_access_token(user_id) }

      it 'successfully decodes the token' do
        payload = described_class.decode_token(token)
        
        expect(payload['user_id']).to eq(user_id)
        expect(payload['type']).to eq('access')
      end
    end

    context 'with valid refresh token' do
      let(:token) { described_class.encode_refresh_token(user_id) }

      it 'successfully decodes the token' do
        payload = described_class.decode_token(token)
        
        expect(payload['user_id']).to eq(user_id)
        expect(payload['type']).to eq('refresh')
      end
    end

    context 'with expired token' do
      let(:expired_token) do
        payload = {
          user_id: user_id,
          exp: 1.hour.ago.to_i,
          type: 'access'
        }
        JWT.encode(payload, secret_key, 'HS256')
      end

      it 'raises an error for expired token' do
        expect { described_class.decode_token(expired_token) }
          .to raise_error(StandardError, 'Token has expired')
      end
    end

    context 'with invalid token format' do
      let(:invalid_token) { 'invalid.token.format' }

      it 'raises an error for invalid token' do
        expect { described_class.decode_token(invalid_token) }
          .to raise_error(StandardError, 'Invalid token')
      end
    end

    context 'with token signed with wrong secret' do
      let(:wrong_secret_token) do
        payload = {
          user_id: user_id,
          exp: 1.hour.from_now.to_i,
          type: 'access'
        }
        JWT.encode(payload, 'wrong_secret', 'HS256')
      end

      it 'raises an error for invalid signature' do
        expect { described_class.decode_token(wrong_secret_token) }
          .to raise_error(StandardError, 'Invalid token')
      end
    end

    context 'with malformed token' do
      let(:malformed_token) { 'not.a.token' }

      it 'raises an error for malformed token' do
        expect { described_class.decode_token(malformed_token) }
          .to raise_error(StandardError, 'Invalid token')
      end
    end
  end

  describe '.generate_token_pair' do
    let(:token_pair) { described_class.generate_token_pair(user_id) }

    it 'returns both access and refresh tokens' do
      expect(token_pair).to have_key(:access_token)
      expect(token_pair).to have_key(:refresh_token)
      expect(token_pair[:access_token]).to be_a(String)
      expect(token_pair[:refresh_token]).to be_a(String)
    end

    it 'generates different tokens' do
      expect(token_pair[:access_token]).not_to eq(token_pair[:refresh_token])
    end

    it 'generates valid tokens' do
      access_payload = described_class.decode_token(token_pair[:access_token])
      refresh_payload = described_class.decode_token(token_pair[:refresh_token])

      expect(access_payload['user_id']).to eq(user_id)
      expect(access_payload['type']).to eq('access')
      expect(refresh_payload['user_id']).to eq(user_id)
      expect(refresh_payload['type']).to eq('refresh')
    end

    it 'sets different expiration times' do
      access_payload = described_class.decode_token(token_pair[:access_token])
      refresh_payload = described_class.decode_token(token_pair[:refresh_token])

      # Refresh token should expire much later than access token
      expect(refresh_payload['exp']).to be > access_payload['exp']
    end
  end

  describe 'token expiration constants' do
    it 'has correct expiration times' do
      expect(JwtService::ACCESS_TOKEN_EXPIRATION).to eq(1.hour)
      expect(JwtService::REFRESH_TOKEN_EXPIRATION).to eq(30.days)
    end
  end

  describe 'edge cases' do
    context 'with different user IDs' do
      let(:user1_token) { described_class.encode_access_token(1) }
      let(:user2_token) { described_class.encode_access_token(2) }

      it 'generates different tokens for different users' do
        expect(user1_token).not_to eq(user2_token)
      end

      it 'decodes to correct user IDs' do
        user1_payload = described_class.decode_token(user1_token)
        user2_payload = described_class.decode_token(user2_token)

        expect(user1_payload['user_id']).to eq(1)
        expect(user2_payload['user_id']).to eq(2)
      end
    end

    context 'with string user ID' do
      let(:string_user_id) { '123' }
      let(:token) { described_class.encode_access_token(string_user_id) }

      it 'handles string user IDs' do
        payload = described_class.decode_token(token)
        expect(payload['user_id']).to eq(string_user_id)
      end
    end

    context 'with nil user ID' do
      it 'raises an error' do
        expect { described_class.encode_access_token(nil) }
          .to raise_error
      end
    end
  end

  describe 'security considerations' do
    it 'uses the application secret key' do
      expect(described_class.send(:secret_key)).to eq(Rails.application.credentials.secret_key_base)
    end

    it 'uses HS256 algorithm' do
      token = described_class.encode_access_token(user_id)
      header = JSON.parse(Base64.decode64(token.split('.')[0]))
      expect(header['alg']).to eq('HS256')
    end

    it 'generates unique tokens for same user at different times' do
      token1 = described_class.encode_access_token(user_id)
      sleep(1) # Ensure different timestamps
      token2 = described_class.encode_access_token(user_id)

      expect(token1).not_to eq(token2)
    end
  end
end