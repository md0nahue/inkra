require 'rails_helper'

RSpec.describe Api::AuthController, type: :controller do
  let(:user) { create(:user) }
  let(:valid_password) { 'password123' }
  let(:invalid_password) { 'wrongpassword' }

  describe 'POST #register' do
    let(:valid_user_params) do
      {
        user: {
          email: 'test@example.com',
          password: valid_password,
          password_confirmation: valid_password
        }
      }
    end

    context 'with valid parameters' do
      it 'creates a new user' do
        expect {
          post :register, params: valid_user_params
        }.to change(User, :count).by(1)
      end

      it 'returns user data with tokens' do
        post :register, params: valid_user_params
        
        expect(response).to have_http_status(:created)
        json_response = JSON.parse(response.body)
        
        expect(json_response).to have_key('user')
        expect(json_response).to have_key('access_token')
        expect(json_response).to have_key('refresh_token')
        expect(json_response['user']['email']).to eq('test@example.com')
      end

      it 'stores refresh token digest in user' do
        post :register, params: valid_user_params
        
        created_user = User.last
        expect(created_user.refresh_token_digest).to be_present
      end

      it 'generates valid JWT tokens' do
        post :register, params: valid_user_params
        
        json_response = JSON.parse(response.body)
        access_token = json_response['access_token']
        refresh_token = json_response['refresh_token']
        
        expect { JwtService.decode_token(access_token) }.not_to raise_error
        expect { JwtService.decode_token(refresh_token) }.not_to raise_error
      end
    end

    context 'with invalid parameters' do
      it 'returns errors for missing email' do
        invalid_params = { user: { password: valid_password, password_confirmation: valid_password } }
        post :register, params: invalid_params
        
        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to include("Email can't be blank")
      end

      it 'returns errors for password mismatch' do
        invalid_params = {
          user: {
            email: 'test@example.com',
            password: valid_password,
            password_confirmation: 'different_password'
          }
        }
        post :register, params: invalid_params
        
        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to include("Password confirmation doesn't match Password")
      end

      it 'returns errors for duplicate email' do
        create(:user, email: 'test@example.com')
        
        post :register, params: valid_user_params
        
        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to include('Email has already been taken')
      end

      it 'returns errors for invalid email format' do
        invalid_params = {
          user: {
            email: 'invalid-email',
            password: valid_password,
            password_confirmation: valid_password
          }
        }
        post :register, params: invalid_params
        
        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to include('Email is invalid')
      end
    end

    context 'when an unexpected error occurs' do
      before do
        allow(User).to receive(:new).and_raise(StandardError, 'Database error')
      end

      it 'returns internal server error' do
        post :register, params: valid_user_params
        
        expect(response).to have_http_status(:internal_server_error)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Registration failed')
      end
    end
  end

  describe 'POST #login' do
    let(:login_params) do
      {
        email: user.email,
        password: valid_password
      }
    end

    context 'with valid credentials' do
      it 'returns user data with tokens' do
        post :login, params: login_params
        
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        
        expect(json_response).to have_key('user')
        expect(json_response).to have_key('access_token')
        expect(json_response).to have_key('refresh_token')
        expect(json_response['user']['email']).to eq(user.email)
      end

      it 'updates user refresh token digest' do
        expect {
          post :login, params: login_params
        }.to change { user.reload.refresh_token_digest }
      end

      it 'handles case insensitive email' do
        post :login, params: { email: user.email.upcase, password: valid_password }
        
        expect(response).to have_http_status(:ok)
      end
    end

    context 'with invalid credentials' do
      it 'returns unauthorized for wrong password' do
        post :login, params: { email: user.email, password: invalid_password }
        
        expect(response).to have_http_status(:unauthorized)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Invalid email or password')
      end

      it 'returns unauthorized for non-existent email' do
        post :login, params: { email: 'nonexistent@example.com', password: valid_password }
        
        expect(response).to have_http_status(:unauthorized)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Invalid email or password')
      end

      it 'returns unauthorized for missing email' do
        post :login, params: { password: valid_password }
        
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when an unexpected error occurs' do
      before do
        allow(User).to receive(:find_by).and_raise(StandardError, 'Database error')
      end

      it 'returns internal server error' do
        post :login, params: login_params
        
        expect(response).to have_http_status(:internal_server_error)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Login failed')
      end
    end
  end

  describe 'POST #refresh' do
    let(:refresh_token) { JwtService.encode_refresh_token(user.id) }
    let(:access_token) { JwtService.encode_access_token(user.id) }

    before do
      user.update!(refresh_token_digest: BCrypt::Password.create(refresh_token))
    end

    context 'with valid refresh token' do
      it 'returns new token pair' do
        # Wait a second to ensure different timestamps
        sleep(1)
        post :refresh, params: { refresh_token: refresh_token }
        
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        
        expect(json_response).to have_key('access_token')
        expect(json_response).to have_key('refresh_token')
        expect(json_response['access_token']).not_to eq(access_token)
        expect(json_response['refresh_token']).not_to eq(refresh_token)
      end

      it 'updates user refresh token digest' do
        expect {
          post :refresh, params: { refresh_token: refresh_token }
        }.to change { user.reload.refresh_token_digest }
      end
    end

    context 'with invalid refresh token' do
      it 'returns unauthorized for access token' do
        post :refresh, params: { refresh_token: access_token }
        
        expect(response).to have_http_status(:unauthorized)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Invalid token type')
      end

      it 'returns unauthorized for non-matching stored token' do
        # Create a token but don't update the user's stored digest to match
        different_refresh_token = JwtService.encode_refresh_token(user.id)
        
        post :refresh, params: { refresh_token: different_refresh_token }
        
        expect(response).to have_http_status(:unauthorized)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Invalid refresh token')
      end

      it 'returns unauthorized for expired token' do
        expired_token = JWT.encode({
          user_id: user.id,
          exp: 1.hour.ago.to_i,
          type: 'refresh'
        }, Rails.application.credentials.secret_key_base, 'HS256')
        
        post :refresh, params: { refresh_token: expired_token }
        
        expect(response).to have_http_status(:unauthorized)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Token refresh failed')
      end

      it 'returns unauthorized for malformed token' do
        post :refresh, params: { refresh_token: 'invalid.token.here' }
        
        expect(response).to have_http_status(:unauthorized)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Token refresh failed')
      end

      it 'returns unauthorized for non-existent user' do
        non_existent_user_token = JwtService.encode_refresh_token(99999)
        post :refresh, params: { refresh_token: non_existent_user_token }
        
        expect(response).to have_http_status(:unauthorized)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Token refresh failed')
      end
    end
  end

  describe 'POST #logout' do
    context 'when user is authenticated' do
      let(:access_token) { JwtService.encode_access_token(user.id) }
      
      before do
        user.update!(refresh_token_digest: BCrypt::Password.create('some_token'))
        request.headers['Authorization'] = "Bearer #{access_token}"
      end

      it 'clears user refresh token' do
        post :logout
        
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['message']).to eq('Logged out successfully')
        expect(user.reload.refresh_token_digest).to be_nil
      end
    end

    context 'when user is not authenticated' do
      it 'returns unauthorized' do
        post :logout
        
        expect(response).to have_http_status(:unauthorized)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Missing authorization token')
      end
    end
  end

  describe 'private methods' do
    describe '#user_response' do
      it 'returns formatted user data' do
        user_data = controller.send(:user_response, user)
        
        expect(user_data).to include(
          id: user.id,
          email: user.email,
          is_premium: user.is_premium,
          subscription_expires_at: user.subscription_expires_at,
          created_at: user.created_at
        )
      end

      it 'includes premium user data' do
        premium_user = create(:user, :premium)
        user_data = controller.send(:user_response, premium_user)
        
        expect(user_data[:is_premium]).to be true
        expect(user_data[:subscription_expires_at]).to be_present
      end
    end
  end
end