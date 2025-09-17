#!/usr/bin/env ruby

require 'httparty'
require 'json'
require 'base64'
require 'net/http'
require 'uri'

class UploadTester
  include HTTParty
  base_uri 'http://localhost:3000/api'

  def initialize
    @email = "test@example.com"
    @password = "password123"
    @tokens = nil
    @project_id = nil
    @audio_file_path = find_audio_file
  end

  def run_full_test
    puts "\n🚀 Starting upload test flow...\n"
    
    # Step 1: Login
    login
    
    # Step 2: Get or create project
    get_or_create_project
    
    # Step 3: Request upload URL
    upload_response = request_upload_url
    
    # Step 4: Upload to S3
    upload_to_s3(upload_response)
    
    # Step 5: Notify upload complete
    notify_upload_complete(upload_response['audioSegmentId'])
    
    puts "\n✅ Test completed successfully!"
  rescue => e
    puts "\n❌ Error: #{e.message}"
    puts e.backtrace.join("\n")
  end

  private

  def find_audio_file
    # Look for test audio files
    audio_paths = [
      "/Users/magnusfremont/Desktop/VibeWriter/test_audio.m4a",
      "/Users/magnusfremont/Desktop/VibeWriter/sample_audio.m4a",
      "/Users/magnusfremont/Desktop/test_audio.m4a",
      "/Users/magnusfremont/Desktop/sample_audio.m4a"
    ]
    
    audio_file = audio_paths.find { |path| File.exist?(path) }
    
    unless audio_file
      # Create a small dummy audio file for testing
      audio_file = "/tmp/test_audio.m4a"
      File.write(audio_file, "dummy audio data for testing")
      puts "⚠️  No audio file found, created dummy at: #{audio_file}"
    end
    
    puts "📁 Using audio file: #{audio_file}"
    audio_file
  end

  def login
    puts "\n1️⃣ Logging in..."
    response = self.class.post('/auth/login', 
      body: { email: @email, password: @password }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )
    
    debug_response("Login", response)
    
    if response.code == 200
      @tokens = response.parsed_response
      puts "✅ Login successful! Access token: #{@tokens['access_token'][0..20]}..."
    else
      raise "Login failed with status #{response.code}: #{response.body}"
    end
  end

  def get_or_create_project
    puts "\n2️⃣ Getting project list..."
    response = self.class.get('/projects',
      headers: auth_headers
    )
    
    debug_response("Get Projects", response)
    
    if response.code == 200 && response.parsed_response['projects'].any?
      @project_id = response.parsed_response['projects'].first['id']
      puts "✅ Using existing project ID: #{@project_id}"
    else
      create_project
    end
  end

  def create_project
    puts "\n2️⃣ Creating new project..."
    response = self.class.post('/projects',
      body: {
        title: "Test Upload Project #{Time.now.to_i}",
        description: "Testing S3 upload"
      }.to_json,
      headers: auth_headers
    )
    
    debug_response("Create Project", response)
    
    if response.code == 201
      @project_id = response.parsed_response['project']['id']
      puts "✅ Created project ID: #{@project_id}"
    else
      raise "Failed to create project: #{response.body}"
    end
  end

  def request_upload_url
    puts "\n3️⃣ Requesting upload URL..."
    
    file_size = File.size(@audio_file_path)
    
    request_body = {
      fileName: "test_audio_#{Time.now.to_i}.m4a",
      mimeType: "audio/m4a",
      recordedDurationSeconds: 30.5,
      questionId: nil
    }
    
    puts "📤 Request body: #{JSON.pretty_generate(request_body)}"
    
    response = self.class.post("/projects/#{@project_id}/audio/upload-request",
      body: request_body.to_json,
      headers: auth_headers
    )
    
    debug_response("Upload Request", response)
    
    if response.code == 200
      puts "✅ Got upload URL!"
      puts "📋 Upload URL: #{response.parsed_response['uploadUrl']}"
      puts "🆔 Audio Segment ID: #{response.parsed_response['audioSegmentId']}"
      response.parsed_response
    else
      raise "Failed to get upload URL: #{response.body}"
    end
  end

  def upload_to_s3(upload_response)
    puts "\n4️⃣ Uploading to S3..."
    
    upload_url = upload_response['uploadUrl']
    audio_data = File.read(@audio_file_path, mode: 'rb')
    
    puts "📦 File size: #{audio_data.size} bytes"
    puts "🔗 Uploading to: #{upload_url[0..100]}..."
    
    # Parse the URL
    uri = URI.parse(upload_url)
    
    # Check if it's a mock URL
    if uri.host == 'localhost'
      puts "⚠️  Detected localhost URL - using mock upload"
      # For mock URLs, just simulate success
      puts "✅ Mock upload successful!"
      return
    end
    
    # Real S3 upload
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    
    request = Net::HTTP::Put.new(uri)
    request['Content-Type'] = 'audio/m4a'
    request['Content-Length'] = audio_data.size.to_s
    request.body = audio_data
    
    puts "🚀 Sending PUT request to S3..."
    response = http.request(request)
    
    puts "📥 S3 Response:"
    puts "   Status: #{response.code} #{response.message}"
    puts "   Headers: #{response.to_hash.inspect}"
    puts "   Body: #{response.body}" if response.body && !response.body.empty?
    
    if response.code.to_i >= 200 && response.code.to_i < 300
      puts "✅ Upload to S3 successful!"
    else
      puts "\n❌ S3 Upload failed!"
      puts "Debug info:"
      puts "- URL Host: #{uri.host}"
      puts "- URL Path: #{uri.path}"
      puts "- Query String: #{uri.query}"
      
      # Try to parse AWS error
      if response.body && response.body.include?('<?xml')
        puts "\nAWS Error Response:"
        puts response.body
      end
      
      raise "S3 upload failed with status #{response.code}"
    end
  end

  def notify_upload_complete(audio_segment_id, success = true)
    puts "\n5️⃣ Notifying upload complete..."
    
    request_body = {
      audioSegmentId: audio_segment_id,
      uploadStatus: success ? 'success' : 'failed',
      errorMessage: success ? nil : 'Test failure'
    }
    
    puts "📤 Request body: #{JSON.pretty_generate(request_body)}"
    
    response = self.class.post("/projects/#{@project_id}/audio/#{audio_segment_id}/upload-complete",
      body: request_body.to_json,
      headers: auth_headers
    )
    
    debug_response("Upload Complete", response)
    
    if response.code == 200
      puts "✅ Upload complete notification successful!"
    else
      raise "Failed to notify upload complete: #{response.body}"
    end
  end

  def auth_headers
    {
      'Content-Type' => 'application/json',
      'Authorization' => "Bearer #{@tokens['access_token']}"
    }
  end

  def debug_response(action, response)
    puts "\n🔍 #{action} Response:"
    puts "   Status: #{response.code}"
    puts "   Headers: #{response.headers.inspect}"
    puts "   Body: #{JSON.pretty_generate(response.parsed_response)}" rescue puts "   Body: #{response.body}"
    puts ""
  end
end

# Check Rails server
def check_rails_server
  response = HTTParty.get('http://localhost:3000/up')
  puts "✅ Rails server is running!" if response.code == 200
rescue => e
  puts "❌ Rails server is not running! Start it with: cd vibewrite_rails && rails server"
  exit 1
end

# Main execution
if __FILE__ == $0
  check_rails_server
  UploadTester.new.run_full_test
end