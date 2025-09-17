#!/usr/bin/env ruby

# Load Rails environment
require File.expand_path('../config/environment', __FILE__)

# Create test user
begin
  user = User.find_or_create_by(email: 'test@example.com') do |u|
    u.password = 'password123'
    u.password_confirmation = 'password123'
  end
  
  puts "✅ Test user created/found: #{user.email} (ID: #{user.id})"
rescue => e
  puts "❌ Failed to create user: #{e.message}"
end