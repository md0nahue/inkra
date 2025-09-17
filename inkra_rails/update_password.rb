user = User.find_by(email: "test@example.com")
if user
  user.update!(password: "password123", password_confirmation: "password123")
  puts "Password updated for test@example.com"
else
  puts "User not found"
end