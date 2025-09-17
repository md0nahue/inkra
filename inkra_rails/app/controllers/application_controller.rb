class ApplicationController < ActionController::Base
  # Base controller for Rails web application
  # No authentication by default - web controllers handle their own auth as needed

  private

  def authenticate_request!
    Rails.logger.debug "=== AUTHENTICATION DEBUG ==="
    Rails.logger.debug "Request path: #{request.path}"
    Rails.logger.debug "Request method: #{request.method}"
    Rails.logger.debug "Authorization header: #{request.headers['Authorization']}"
    Rails.logger.debug "All headers: #{request.headers.to_h.select { |k,v| k.downcase.include?('auth') }}"
    
    # Skip authentication in development/test if bypass flag is set
    if (Rails.env.development? || Rails.env.test?) && ENV['DEV_SKIP_AUTH'] == 'true'
      Rails.logger.debug "Skipping auth due to DEV_SKIP_AUTH flag"
      # Set a default user for tests - use the first user or create one
      @current_user = User.first || User.create!(
        email: 'test@example.com', 
        password: 'password123',
        is_premium: false
      )
      return 
    end
    
    token = extract_token_from_header
    Rails.logger.debug "Extracted token: #{token ? '[PRESENT]' : '[MISSING]'}"
    
    unless token
      Rails.logger.debug "No token found, rendering unauthorized"
      return render_unauthorized('Missing authorization token')
    end

    begin
      decoded_token = JwtService.decode_token(token)
      Rails.logger.debug "Decoded token: #{decoded_token.inspect}"
      
      unless decoded_token['type'] == 'access'
        Rails.logger.debug "Invalid token type: #{decoded_token['type']}"
        return render_unauthorized('Invalid token type')
      end
      
      user_id = decoded_token['user_id']
      Rails.logger.debug "Looking up user with ID: #{user_id}"
      
      @current_user = User.find_by(id: user_id)
      unless @current_user
        Rails.logger.debug "User not found with ID: #{user_id}"
        return render_unauthorized('User not found')
      end
      
      Rails.logger.debug "Authentication successful for user: #{@current_user.email}"
    rescue StandardError => e
      Rails.logger.error "Authentication failed: #{e.class}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render_unauthorized('Invalid or expired token')
    end
  end

  def current_user
    @current_user
  end

  def authenticate_user!
    # For web controllers, we'll use a simple session-based approach
    # In a real app, you'd integrate with Devise or similar
    unless session[:user_id] && (@current_user = User.find_by(id: session[:user_id]))
      redirect_to '/login', notice: 'Please log in to continue'
    end
  end

  def render_unauthorized(message = 'Unauthorized')
    render json: { 
      message: message, 
      code: 'UNAUTHORIZED',
      details: {}
    }, status: :unauthorized
  end

  private

  def extract_token_from_header
    authorization_header = request.headers['Authorization']
    return nil unless authorization_header
    
    # Extract token from "Bearer <token>" format
    authorization_header.split(' ').last if authorization_header.start_with?('Bearer ')
  end
end
