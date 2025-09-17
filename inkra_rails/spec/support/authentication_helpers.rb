module AuthenticationHelpers
  def authenticate_user!
    # Mock authentication for tests
    true
  end

  def current_user
    @current_user ||= create(:user)
  end
end

RSpec.configure do |config|
  config.include AuthenticationHelpers, type: :request
  config.include AuthenticationHelpers, type: :controller
end