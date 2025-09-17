require 'test_helper'

class Admin::AdminAuthenticationTest < ActionController::TestCase
  test "admin authentication should require admin user" do
    # Test with no user
    get admin_presets_path
    assert_response :unauthorized
    
    # Test with regular user
    regular_user = User.create!(email: 'user@example.com', password: 'password123', admin: false)
    sign_in_as(regular_user)
    get admin_presets_path
    assert_response :forbidden
    
    # Test with admin user
    admin_user = User.create!(email: 'admin@example.com', password: 'password123', admin: true)
    sign_in_as(admin_user)
    get admin_presets_path
    assert_response :success
  end
  
  private
  
  def sign_in_as(user)
    token = JwtService.generate_tokens(user)[:access_token]
    @request.headers['Authorization'] = "Bearer #{token}"
  end
end