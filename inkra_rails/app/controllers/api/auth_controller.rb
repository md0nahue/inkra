class Api::AuthController < Api::BaseController
  skip_before_action :authenticate_api_request!, only: [:register, :login, :refresh]

  # Test Harness Status: ✅ Comprehensive test coverage with happy/sad paths
  def register
    Rails.logger.info "🔐 [RAILS_AUTH] Registration attempt for email: #{params[:user][:email] rescue 'unknown'}"
    Rails.logger.info "🔐 [RAILS_AUTH] User params received: #{user_params.inspect}"
    
    user = User.new(user_params)
    Rails.logger.info "🔐 [RAILS_AUTH] User object created, valid: #{user.valid?}"
    
    if user.valid?
      Rails.logger.info "🔐 [RAILS_AUTH] User validation passed, attempting save..."
    else
      Rails.logger.warn "❌ [RAILS_AUTH] User validation failed: #{user.errors.full_messages}"
    end
    
    if user.save
      Rails.logger.info "🔐 [RAILS_AUTH] User saved successfully with ID: #{user.id}"
      Rails.logger.info "🔐 [RAILS_AUTH] Generating token pair..."
      
      tokens = JwtService.generate_token_pair(user.id)
      Rails.logger.info "🔐 [RAILS_AUTH] Tokens generated - AccessToken length: #{tokens[:access_token].length}, RefreshToken length: #{tokens[:refresh_token].length}"
      
      Rails.logger.info "🔐 [RAILS_AUTH] Updating user with refresh token digest..."
      user.update!(refresh_token_digest: BCrypt::Password.create(tokens[:refresh_token]))
      Rails.logger.info "🔐 [RAILS_AUTH] Refresh token digest stored successfully"
      
      pp tokens
      response_data = {
        user: user_response(user),
        access_token: tokens[:access_token],
        refresh_token: tokens[:refresh_token]
      }
      
      pp response_data
      Rails.logger.info "🔐 [RAILS_AUTH] Registration response prepared - User ID: #{response_data[:user][:id]}, Email: #{response_data[:user][:email]}"
      Rails.logger.info "🔐 [RAILS_AUTH] Response includes access_token: #{response_data[:access_token].present?}, refresh_token: #{response_data[:refresh_token].present?}"
      
      render json: response_data, status: :created
    else
      Rails.logger.warn "❌ [RAILS_AUTH] User save failed: #{user.errors.full_messages}"
      pp user.errors.full_messages
      render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
    end
  rescue StandardError => e
    Rails.logger.error "❌ [RAILS_AUTH] Registration exception: #{e.class.name} - #{e.message}"
    Rails.logger.error "❌ [RAILS_AUTH] Backtrace: #{e.backtrace.first(5).join(', ')}"
    render json: { error: 'Registration failed' }, status: :internal_server_error
  end

  # Test Harness Status: ✅ Comprehensive test coverage with happy/sad paths
  def login
    email = params[:email]&.downcase
    Rails.logger.info "🔐 [RAILS_AUTH] Login attempt for email: #{email}"
    Rails.logger.info "🔐 [RAILS_AUTH] Password provided: #{params[:password].present?}"
    
    user = User.find_by(email: email)
    Rails.logger.info "🔐 [RAILS_AUTH] User found: #{user.present?}"
    
    if user
      Rails.logger.info "🔐 [RAILS_AUTH] User exists (ID: #{user.id}), attempting authentication..."
      auth_result = user.authenticate(params[:password])
      Rails.logger.info "🔐 [RAILS_AUTH] Authentication result: #{auth_result.present?}"
    else
      Rails.logger.warn "❌ [RAILS_AUTH] No user found with email: #{email}"
    end
    
    if user&.authenticate(params[:password])
      Rails.logger.info "🔐 [RAILS_AUTH] Authentication successful, generating tokens..."
      
      tokens = JwtService.generate_token_pair(user.id)
      Rails.logger.info "🔐 [RAILS_AUTH] Tokens generated - AccessToken length: #{tokens[:access_token].length}, RefreshToken length: #{tokens[:refresh_token].length}"
      
      Rails.logger.info "🔐 [RAILS_AUTH] Updating user with refresh token digest..."
      user.update!(refresh_token_digest: BCrypt::Password.create(tokens[:refresh_token]))
      Rails.logger.info "🔐 [RAILS_AUTH] Refresh token digest stored successfully"
      
      response_data = {
        user: user_response(user),
        access_token: tokens[:access_token],
        refresh_token: tokens[:refresh_token]
      }
      Rails.logger.info "🔐 [RAILS_AUTH] Login response prepared - User ID: #{response_data[:user][:id]}, Email: #{response_data[:user][:email]}"
      Rails.logger.info "🔐 [RAILS_AUTH] Response includes access_token: #{response_data[:access_token].present?}, refresh_token: #{response_data[:refresh_token].present?}"
      
      render json: response_data
    else
      Rails.logger.warn "❌ [RAILS_AUTH] Login failed - invalid credentials for email: #{email}"
      render json: { error: 'Invalid email or password' }, status: :unauthorized
    end
  rescue StandardError => e
    Rails.logger.error "❌ [RAILS_AUTH] Login exception: #{e.class.name} - #{e.message}"
    Rails.logger.error "❌ [RAILS_AUTH] Backtrace: #{e.backtrace.first(5).join(', ')}"
    render json: { error: 'Login failed' }, status: :internal_server_error
  end

  # Test Harness Status: ✅ Comprehensive test coverage with happy/sad paths
  def refresh
    Rails.logger.info "🔐 [RAILS_AUTH] Token refresh attempt"
    Rails.logger.info "🔐 [RAILS_AUTH] Refresh token provided: #{params[:refresh_token].present?}"
    
    begin
      Rails.logger.info "🔐 [RAILS_AUTH] Decoding refresh token..."
      refresh_payload = JwtService.decode_token(params[:refresh_token])
      Rails.logger.info "🔐 [RAILS_AUTH] Token decoded successfully, type: #{refresh_payload['type']}, user_id: #{refresh_payload['user_id']}"
      
      unless refresh_payload['type'] == 'refresh'
        Rails.logger.warn "❌ [RAILS_AUTH] Invalid token type: #{refresh_payload['type']}"
        return render json: { error: 'Invalid token type' }, status: :unauthorized
      end
      
      Rails.logger.info "🔐 [RAILS_AUTH] Finding user with ID: #{refresh_payload['user_id']}"
      user = User.find(refresh_payload['user_id'])
      Rails.logger.info "🔐 [RAILS_AUTH] User found: #{user.email}"
      
      # Verify the refresh token matches what we have stored
      Rails.logger.info "🔐 [RAILS_AUTH] Verifying refresh token against stored digest..."
      token_valid = user.refresh_token_digest && BCrypt::Password.new(user.refresh_token_digest) == params[:refresh_token]
      Rails.logger.info "🔐 [RAILS_AUTH] Token verification result: #{token_valid}"
      
      unless token_valid
        Rails.logger.warn "❌ [RAILS_AUTH] Refresh token verification failed for user: #{user.email}"
        return render json: { error: 'Invalid refresh token' }, status: :unauthorized
      end
      
      Rails.logger.info "🔐 [RAILS_AUTH] Generating new token pair..."
      tokens = JwtService.generate_token_pair(user.id)
      Rails.logger.info "🔐 [RAILS_AUTH] New tokens generated - AccessToken length: #{tokens[:access_token].length}, RefreshToken length: #{tokens[:refresh_token].length}"
      
      Rails.logger.info "🔐 [RAILS_AUTH] Updating refresh token digest..."
      user.update!(refresh_token_digest: BCrypt::Password.create(tokens[:refresh_token]))
      Rails.logger.info "🔐 [RAILS_AUTH] Refresh token digest updated successfully"
      
      response_data = {
        access_token: tokens[:access_token],
        refresh_token: tokens[:refresh_token]
      }
      Rails.logger.info "🔐 [RAILS_AUTH] Refresh response prepared - includes access_token: #{response_data[:access_token].present?}, refresh_token: #{response_data[:refresh_token].present?}"
      
      render json: response_data
    rescue StandardError => e
      Rails.logger.error "❌ [RAILS_AUTH] Token refresh exception: #{e.class.name} - #{e.message}"
      Rails.logger.error "❌ [RAILS_AUTH] Backtrace: #{e.backtrace.first(5).join(', ')}"
      render json: { error: 'Token refresh failed' }, status: :unauthorized
    end
  end

  # Test Harness Status: ✅ Comprehensive test coverage with happy/sad paths
  def logout
    Rails.logger.info "🔐 [RAILS_AUTH] Logout attempt"
    Rails.logger.info "🔐 [RAILS_AUTH] Current user present: #{current_user.present?}"
    
    if current_user
      Rails.logger.info "🔐 [RAILS_AUTH] Logging out user: #{current_user.email} (ID: #{current_user.id})"
      Rails.logger.info "🔐 [RAILS_AUTH] Clearing refresh token digest..."
      
      current_user.update!(refresh_token_digest: nil)
      Rails.logger.info "🔐 [RAILS_AUTH] Refresh token digest cleared successfully"
      
      render json: { message: 'Logged out successfully' }
    else
      Rails.logger.warn "❌ [RAILS_AUTH] Logout attempt without authenticated user"
      render json: { error: 'Not logged in' }, status: :unauthorized
    end
  end

  private

  def user_params
    params.require(:user).permit(:email, :password, :password_confirmation)
  end

  def user_response(user)
    Rails.logger.info "🔐 [RAILS_AUTH] Building user response for ID: #{user.id}, Email: #{user.email}"
    Rails.logger.info "🔐 [RAILS_AUTH] User created_at: #{user.created_at}"
    
    response = {
      id: user.id,
      email: user.email,
      created_at: user.created_at.iso8601,
      interests: user.interests || []
    }
    
    Rails.logger.info "🔐 [RAILS_AUTH] User response built: #{response.inspect}"
    response
  end
end