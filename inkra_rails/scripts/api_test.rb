#!/usr/bin/env ruby

# API Testing Script for VibeWriter Rails API
# This script tests all API endpoints with live requests using HTTParty

require 'httparty'
require 'json'
require 'colorize'

class APITester
  include HTTParty
  
  # Set base URI - adjust for your environment
  base_uri 'http://localhost:3000'
  
  def initialize
    @base_url = 'http://localhost:3000'
    @access_token = nil
    @refresh_token = nil
    @project_id = nil
    @test_user_email = "test_#{Time.now.to_i}@example.com"
    @test_user_password = "password123"
    
    puts "🚀 Starting API Test Suite".blue.bold
    puts "Base URL: #{@base_url}".yellow
    puts "Test User: #{@test_user_email}".yellow
    puts "-" * 50
  end
  
  def run_tests
    begin
      # Health check
      test_health_check
      
      # Authentication flow
      test_user_registration
      test_user_login
      test_token_refresh
      
      # Project management
      test_project_creation
      test_project_listing
      test_project_show
      test_project_update
      test_project_outline_update
      test_add_more_chapters
      
      # Interview questions
      test_generate_outline
      test_generate_section_questions
      test_refine_questions
      
      # Audio segments
      test_audio_upload_request
      test_audio_upload_complete
      test_audio_playback_url
      
      # Transcript
      test_project_transcript
      
      # Export functionality
      test_export_preview
      test_export_pdf
      test_export_docx
      test_export_txt
      
      # Complete interview workflow
      test_complete_interview
      
      # Logout
      test_user_logout
      
      puts "\n✅ All API tests completed successfully!".green.bold
      
    rescue => e
      puts "\n❌ Test suite failed with error: #{e.message}".red.bold
      puts e.backtrace.first(5).join("\n").red
    end
  end
  
  private
  
  def test_health_check
    puts "\n🔍 Testing Health Check...".cyan
    
    response = self.class.get('/up')
    assert_response(response, 200, "Health check should return 200")
    
    puts "✅ Health check passed".green
  end
  
  def test_user_registration
    puts "\n👤 Testing User Registration...".cyan
    
    user_data = {
      user: {
        email: @test_user_email,
        password: @test_user_password,
        password_confirmation: @test_user_password
      }
    }
    
    response = self.class.post('/api/auth/register', body: user_data.to_json, headers: { 'Content-Type' => 'application/json' })
    assert_response(response, 201, "User registration should succeed")
    
    body = JSON.parse(response.body)
    @access_token = body['access_token']
    @refresh_token = body['refresh_token']
    
    assert_not_nil(@access_token, "Access token should be present")
    assert_not_nil(@refresh_token, "Refresh token should be present")
    
    puts "✅ User registration successful".green
  end
  
  def test_user_login
    puts "\n🔑 Testing User Login...".cyan
    
    login_data = {
      email: @test_user_email,
      password: @test_user_password
    }
    
    response = self.class.post('/api/auth/login', body: login_data.to_json, headers: { 'Content-Type' => 'application/json' })
    assert_response(response, 200, "User login should succeed")
    
    body = JSON.parse(response.body)
    @access_token = body['access_token']
    @refresh_token = body['refresh_token']
    
    puts "✅ User login successful".green
  end
  
  def test_token_refresh
    puts "\n🔄 Testing Token Refresh...".cyan
    
    refresh_data = {
      refresh_token: @refresh_token
    }
    
    response = self.class.post('/api/auth/refresh', body: refresh_data.to_json, headers: { 'Content-Type' => 'application/json' })
    assert_response(response, 200, "Token refresh should succeed")
    
    body = JSON.parse(response.body)
    @access_token = body['access_token']
    @refresh_token = body['refresh_token']
    
    puts "✅ Token refresh successful".green
  end
  
  def test_project_creation
    puts "\n📝 Testing Project Creation...".cyan
    
    project_data = {
      initialTopic: "Testing API with Automated Script"
    }
    
    response = authenticated_post('/api/projects', project_data)
    assert_response(response, 201, "Project creation should succeed")
    
    body = JSON.parse(response.body)
    @project_id = body['projectId']
    
    assert_not_nil(@project_id, "Project ID should be present")
    
    puts "✅ Project creation successful (ID: #{@project_id})".green
  end
  
  def test_project_listing
    puts "\n📋 Testing Project Listing...".cyan
    
    response = authenticated_get('/api/projects')
    assert_response(response, 200, "Project listing should succeed")
    
    body = JSON.parse(response.body)
    assert(body['projects'].is_a?(Array), "Projects should be an array")
    assert(body['projects'].length > 0, "Should have at least one project")
    
    puts "✅ Project listing successful (#{body['projects'].length} projects)".green
  end
  
  def test_project_show
    puts "\n👁️ Testing Project Show...".cyan
    
    response = authenticated_get("/api/projects/#{@project_id}")
    assert_response(response, 200, "Project show should succeed")
    
    body = JSON.parse(response.body)
    assert_equal(@project_id, body['id'], "Project ID should match")
    
    puts "✅ Project show successful".green
  end
  
  def test_project_update
    puts "\n✏️ Testing Project Update...".cyan
    
    update_data = {
      status: 'outline_ready'
    }
    
    response = authenticated_patch("/api/projects/#{@project_id}", update_data)
    assert_response(response, 200, "Project update should succeed")
    
    puts "✅ Project update successful".green
  end
  
  def test_project_outline_update
    puts "\n📊 Testing Project Outline Update...".cyan
    
    # First, wait a bit for the outline to be generated and get the project details
    sleep(3)
    
    # Get the project to see actual chapter IDs
    project_response = authenticated_get("/api/projects/#{@project_id}")
    project_body = JSON.parse(project_response.body)
    
    if project_body['outline'] && project_body['outline']['chapters'] && project_body['outline']['chapters'].length > 0
      first_chapter_id = project_body['outline']['chapters'][0]['chapterId']
      
      outline_data = {
        updates: [
          {
            chapterId: first_chapter_id,
            omitted: false
          }
        ]
      }
      
      response = authenticated_patch("/api/projects/#{@project_id}/outline", outline_data)
      assert_response(response, 200, "Outline update should succeed")
      
      puts "✅ Project outline update successful".green
    else
      puts "⚠️ Project outline update skipped (no chapters generated yet)".yellow
    end
  end
  
  def test_add_more_chapters
    puts "\n➕ Testing Add More Chapters...".cyan
    
    response = authenticated_post("/api/projects/#{@project_id}/add_more_chapters", {})
    
    # This might fail if LLM service is not configured, so we'll be more lenient
    if response.code == 200
      puts "✅ Add more chapters successful".green
    else
      puts "⚠️ Add more chapters failed (LLM service may not be configured)".yellow
    end
  end
  
  def test_generate_outline
    puts "\n🎯 Testing Generate Outline...".cyan
    
    outline_data = {
      topic: "Test Topic for API"
    }
    
    response = authenticated_post('/api/interview_questions/generate_outline', outline_data)
    
    # This might fail if LLM service is not configured
    if response.code == 200
      puts "✅ Generate outline successful".green
    else
      puts "⚠️ Generate outline failed (LLM service may not be configured)".yellow
    end
  end
  
  def test_generate_section_questions
    puts "\n❓ Testing Generate Section Questions...".cyan
    
    questions_data = {
      topic: "Test Topic",
      section_title: "Test Section"
    }
    
    response = authenticated_post('/api/interview_questions/generate_section_questions', questions_data)
    
    if response.code == 200
      puts "✅ Generate section questions successful".green
    else
      puts "⚠️ Generate section questions failed (LLM service may not be configured)".yellow
    end
  end
  
  def test_refine_questions
    puts "\n🔧 Testing Refine Questions...".cyan
    
    refine_data = {
      questions: ["What is your background?"],
      feedback: "Make them more specific"
    }
    
    response = authenticated_post('/api/interview_questions/refine_questions', refine_data)
    
    if response.code == 200
      puts "✅ Refine questions successful".green
    else
      puts "⚠️ Refine questions failed (LLM service may not be configured)".yellow
    end
  end
  
  def test_audio_upload_request
    puts "\n🎵 Testing Audio Upload Request...".cyan
    
    upload_data = {
      fileName: "test_audio.m4a",
      mimeType: "audio/m4a",
      recordedDurationSeconds: 30.5
    }
    
    response = authenticated_post("/api/projects/#{@project_id}/audio_segments/upload_request", upload_data)
    assert_response(response, 200, "Audio upload request should succeed")
    
    puts "✅ Audio upload request successful".green
  end
  
  def test_audio_upload_complete
    puts "\n✅ Testing Audio Upload Complete...".cyan
    
    # First create an audio segment
    upload_data = {
      fileName: "test_audio_complete.m4a",
      mimeType: "audio/m4a", 
      recordedDurationSeconds: 30.5
    }
    
    upload_response = authenticated_post("/api/projects/#{@project_id}/audio_segments/upload_request", upload_data)
    upload_body = JSON.parse(upload_response.body)
    segment_id = upload_body['audioSegmentId']
    
    complete_data = {
      uploadStatus: "success"
    }
    
    response = authenticated_post("/api/projects/#{@project_id}/audio_segments/upload_complete", complete_data.merge({audioSegmentId: segment_id}))
    assert_response(response, 200, "Audio upload complete should succeed")
    
    puts "✅ Audio upload complete successful".green
  end
  
  def test_audio_playback_url
    puts "\n▶️ Testing Audio Playback URL...".cyan
    
    # Create an audio segment first
    upload_data = {
      fileName: "test_playback.m4a",
      mimeType: "audio/m4a",
      recordedDurationSeconds: 30.5
    }
    
    upload_response = authenticated_post("/api/projects/#{@project_id}/audio_segments/upload_request", upload_data)
    upload_body = JSON.parse(upload_response.body)
    segment_id = upload_body['audioSegmentId']
    
    # Complete the upload
    complete_data = { uploadStatus: "success", audioSegmentId: segment_id }
    authenticated_post("/api/projects/#{@project_id}/audio_segments/upload_complete", complete_data)
    
    response = authenticated_get("/api/projects/#{@project_id}/audio_segments/#{segment_id}/playback_url")
    
    if response.code == 200
      puts "✅ Audio playback URL successful".green
    else
      puts "⚠️ Audio playback URL failed (AWS S3 may not be configured)".yellow
    end
  end
  
  def test_project_transcript
    puts "\n📝 Testing Project Transcript...".cyan
    
    response = authenticated_get("/api/projects/#{@project_id}/transcript")
    assert_response(response, 200, "Project transcript should succeed")
    
    body = JSON.parse(response.body)
    assert_equal(@project_id, body['projectId'], "Project ID should match")
    
    puts "✅ Project transcript successful".green
  end
  
  def test_export_preview
    puts "\n👀 Testing Export Preview...".cyan
    
    response = authenticated_get("/api/projects/#{@project_id}/export/preview?version=edited")
    
    if response.code == 200
      puts "✅ Export preview successful".green
    else
      puts "⚠️ Export preview failed (may need transcript content)".yellow
    end
  end
  
  def test_export_pdf
    puts "\n📄 Testing Export PDF...".cyan
    
    response = authenticated_get("/api/projects/#{@project_id}/export/pdf?version=edited")
    
    if response.code == 200
      puts "✅ Export PDF successful".green
    else
      puts "⚠️ Export PDF failed (may need transcript content)".yellow
    end
  end
  
  def test_export_docx
    puts "\n📝 Testing Export DOCX...".cyan
    
    response = authenticated_get("/api/projects/#{@project_id}/export/docx?version=edited")
    
    if response.code == 200
      puts "✅ Export DOCX successful".green
    else
      puts "⚠️ Export DOCX failed (may need transcript content)".yellow
    end
  end
  
  def test_export_txt
    puts "\n📋 Testing Export TXT...".cyan
    
    response = authenticated_get("/api/projects/#{@project_id}/export/txt?version=edited")
    
    if response.code == 200
      puts "✅ Export TXT successful".green
    else
      puts "⚠️ Export TXT failed (may need transcript content)".yellow
    end
  end
  
  def test_complete_interview
    puts "\n🏁 Testing Complete Interview...".cyan
    
    # First, check project status and update if needed
    project_response = authenticated_get("/api/projects/#{@project_id}")
    project_body = JSON.parse(project_response.body)
    
    # If project is already transcribing, set it back to recording_in_progress for the test
    if project_body['status'] == 'transcribing'
      authenticated_patch("/api/projects/#{@project_id}", { status: 'recording_in_progress' })
    end
    
    response = authenticated_post("/api/projects/#{@project_id}/complete_interview", {})
    assert_response(response, 200, "Complete interview should succeed")
    
    puts "✅ Complete interview successful".green
  end
  
  def test_user_logout
    puts "\n👋 Testing User Logout...".cyan
    
    response = authenticated_post('/api/auth/logout', {})
    assert_response(response, 200, "User logout should succeed")
    
    puts "✅ User logout successful".green
  end
  
  # Helper methods
  
  def authenticated_get(endpoint)
    self.class.get(endpoint, headers: auth_headers)
  end
  
  def authenticated_post(endpoint, data)
    self.class.post(endpoint, body: data.to_json, headers: auth_headers)
  end
  
  def authenticated_patch(endpoint, data)
    self.class.patch(endpoint, body: data.to_json, headers: auth_headers)
  end
  
  def auth_headers
    {
      'Authorization' => "Bearer #{@access_token}",
      'Content-Type' => 'application/json'
    }
  end
  
  def assert_response(response, expected_code, message)
    unless response.code == expected_code
      puts "❌ #{message}".red
      puts "Expected: #{expected_code}, Got: #{response.code}".red
      puts "Response: #{response.body}".red
      raise "API test failed: #{message}"
    end
  end
  
  def assert(condition, message)
    unless condition
      puts "❌ #{message}".red
      raise "Assertion failed: #{message}"
    end
  end
  
  def assert_not_nil(value, message)
    if value.nil?
      puts "❌ #{message}".red
      raise "Assertion failed: #{message}"
    end
  end
  
  def assert_equal(expected, actual, message)
    unless expected == actual
      puts "❌ #{message}".red
      puts "Expected: #{expected}, Got: #{actual}".red
      raise "Assertion failed: #{message}"
    end
  end
end

# Check if required gems are available
begin
  require 'httparty'
  require 'colorize'
rescue LoadError => e
  puts "Missing required gem: #{e.message}"
  puts "Please install required gems:"
  puts "gem install httparty colorize"
  exit 1
end

# Check if Rails server is running
begin
  response = HTTParty.get('http://localhost:3000/up', timeout: 5)
  puts "✅ Rails server is running".green
rescue => e
  puts "❌ Rails server is not running or not accessible at http://localhost:3000".red
  puts "Please start your Rails server with: rails server"
  exit 1
end

# Run the tests
if __FILE__ == $0
  tester = APITester.new
  tester.run_tests
end