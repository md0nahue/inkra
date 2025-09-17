# Rate limiting configuration for security
class Rack::Attack
  # Enable caching (required for throttling)
  cache.store = ActiveSupport::Cache::MemoryStore.new
  
  # Authentication endpoint protection
  throttle("auth/ip", limit: 5, period: 1.minute) do |req|
    req.ip if req.path.start_with?('/api/auth') && req.post?
  end
  
  # General API rate limiting
  throttle("api/ip", limit: 100, period: 1.minute) do |req|
    req.ip if req.path.start_with?('/api/')
  end
  
  # More restrictive rate limiting for expensive operations
  throttle("expensive_ops/ip", limit: 10, period: 1.minute) do |req|
    if req.path.match?(/\/api\/(projects|questions|audio_segments)/) && req.post?
      req.ip
    end
  end
  
  # Block obvious attack patterns
  blocklist("block_bad_requests") do |req|
    # Block if trying to access sensitive paths
    req.path.match?(/\/(admin|wp-admin|phpmyadmin|\.env|\.git)/) ||
    # Block if user agent suggests automated tool (exclude curl for development testing)
    req.get_header("HTTP_USER_AGENT")&.match?(/wget|python|bot/i)
  end
  
  # Log blocked requests
  ActiveSupport::Notifications.subscribe("throttle.rack_attack") do |name, start, finish, request_id, payload|
    Rails.logger.warn "Rate limit exceeded: #{payload[:request].ip} - #{payload[:request].path}"
  end
  
  ActiveSupport::Notifications.subscribe("blocklist.rack_attack") do |name, start, finish, request_id, payload|
    Rails.logger.error "Blocked malicious request: #{payload[:request].ip} - #{payload[:request].path}"
  end
end