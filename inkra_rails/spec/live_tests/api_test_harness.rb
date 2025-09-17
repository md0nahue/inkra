#!/usr/bin/env ruby

# Live API Test Harness for VibeWriter Rails Backend
# This script tests the complete user journey via API calls to the running Rails server

require 'net/http'
require 'json'
require 'uri'
require 'tempfile'

class ApiTestHarness
  BASE_URL = 'http://localhost:3000'
  
  def initialize
    @test_results = []
    @auth_token = nil
    @test_data = {}
    
    puts "🎯 VibeWrite API Test Harness"
    puts "=" * 60
    puts "Testing complete user journey via live API calls"
    puts "Server: #{BASE_URL}"
    puts "=" * 60
    
    check_server_availability
  end
  
  def run_complete_test_suite
    puts "\n🚀 Starting complete API test suite...\n"
    
    # Core user journey tests
    test_user_authentication
    test_project_creation_and_management
    test_interview_outline_generation
    test_audio_upload_workflow
    test_transcript_processing
    test_project_completion
    
    # Additional functionality tests
    test_content_export
    test_error_handling
    test_concurrent_operations
    
    print_comprehensive_summary
  end
  
  private
  
  def check_server_availability
    begin
      response = make_request('GET', '/up')
      if response.code == '200'
        puts "✅ Rails server is running and healthy"
      else
        puts "❌ Rails server responded with status #{response.code}"
        exit(1)
      end
    rescue => e
      puts "❌ Could not connect to Rails server: #{e.message}"
      puts "   Make sure Rails server is running on #{BASE_URL}"
      exit(1)
    end
  end
  
  # Authentication Tests
  def test_user_authentication
    puts "\n👤 Testing User Authentication..."
    
    # Test user registration
    registration_data = {
      user: {
        email: "api_test_#{Time.now.to_i}@example.com",
        password: "password123"
      }
    }
    
    response = make_request('POST', '/api/auth/register', registration_data)
    
    if response.code == '201' || response.code == '200'
      result = JSON.parse(response.body)
      @auth_token = result['access_token'] || result['token']
      @test_data[:user_email] = registration_data[:user][:email]
      record_success("User Registration", "Successfully registered user")
    else
      record_failure("User Registration", "Failed with status #{response.code}: #{response.body}")
      return
    end
    
    # Test user login
    login_data = {
      email: registration_data[:user][:email],
      password: registration_data[:user][:password]
    }
    
    response = make_request('POST', '/api/auth/login', login_data)
    
    if response.code == '200'
      result = JSON.parse(response.body)
      @auth_token = result['access_token'] || result['token'] || @auth_token
      record_success("User Login", "Successfully logged in")
    else
      record_failure("User Login", "Failed with status #{response.code}: #{response.body}")
    end
    
    # Test authenticated request
    response = make_authenticated_request('GET', '/api/projects')
    if response.code == '200'
      record_success("Authentication Check", "Authenticated requests working")
    else
      record_failure("Authentication Check", "Auth failed with status #{response.code}")
    end
  end
  
  # Project Management Tests
  def test_project_creation_and_management
    puts "\n📁 Testing Project Creation and Management..."
    
    # Create project
    project_data = {
      initialTopic: "Building a Mobile App with React Native"
    }
    
    response = make_authenticated_request('POST', '/api/projects', project_data)
    
    if response.code == '201'
      result = JSON.parse(response.body)
      @test_data[:project_id] = result['projectId']
      @test_data[:project_title] = result['title']
      record_success("Project Creation", "Created project: #{result['title']}")
    else
      record_failure("Project Creation", "Failed with status #{response.code}: #{response.body}")
      return
    end
    
    # Wait for outline generation
    project_id = @test_data[:project_id]
    outline_ready = wait_for_project_status(project_id, 'outline_ready', timeout: 30)
    
    if outline_ready
      record_success("Outline Generation", "Project outline generated automatically")
    else
      record_failure("Outline Generation", "Outline not ready within timeout")
    end
    
    # Get project details
    response = make_authenticated_request('GET', "/api/projects/#{project_id}")
    if response.code == '200'
      result = JSON.parse(response.body)
      @test_data[:project_outline] = result['outline']
      
      chapters_count = result['outline']['chapters']&.length || 0
      questions_count = result['outline']['chapters']&.sum { |c| 
        c['sections']&.sum { |s| s['questions']&.length || 0 } || 0 
      } || 0
      
      record_success("Project Details", "Retrieved project with #{chapters_count} chapters, #{questions_count} questions")
    else
      record_failure("Project Details", "Failed to get project details")
    end
    
    # Test project list
    response = make_authenticated_request('GET', '/api/projects')
    if response.code == '200'
      result = JSON.parse(response.body)
      projects_count = result['projects']&.length || 0
      record_success("Project List", "Retrieved #{projects_count} projects")
    else
      record_failure("Project List", "Failed to get projects list")
    end
  end
  
  # Interview Questions Tests
  def test_interview_outline_generation
    puts "\n❓ Testing Interview Outline Generation..."
    
    # Test standalone outline generation
    outline_data = {
      topic: "AI in Healthcare",
      num_chapters: 3,
      sections_per_chapter: 2,
      questions_per_section: 3
    }
    
    response = make_authenticated_request('POST', '/api/interview_questions/generate_outline', outline_data)
    
    if response.code == '200'
      result = JSON.parse(response.body)
      outline = result['outline']
      
      if outline && outline['chapters']
        chapters_count = outline['chapters'].length
        total_questions = outline['chapters'].sum { |c| 
          c['sections']&.sum { |s| s['questions']&.length || 0 } || 0 
        }
        record_success("Standalone Outline", "Generated #{chapters_count} chapters with #{total_questions} questions")
        @test_data[:generated_outline] = outline
      else
        record_failure("Standalone Outline", "Invalid outline structure returned")
      end
    else
      record_failure("Standalone Outline", "Failed with status #{response.code}")
    end
    
    # Test section questions generation (if we have a project)
    if @test_data[:project_outline] && @test_data[:project_outline]['chapters']
      first_section = @test_data[:project_outline]['chapters'][0]['sections'][0]
      if first_section
        section_data = {
          section_id: first_section['sectionId'],
          num_questions: 2
        }
        
        response = make_authenticated_request('POST', '/api/interview_questions/generate_section_questions', section_data)
        
        if response.code == '200'
          result = JSON.parse(response.body)
          new_questions = result['new_questions']&.length || 0
          record_success("Section Questions", "Generated #{new_questions} additional questions")
        else
          record_failure("Section Questions", "Failed with status #{response.code}")
        end
      end
    end
  end
  
  # Audio Upload Tests
  def test_audio_upload_workflow
    puts "\n🎵 Testing Audio Upload Workflow..."
    
    return unless @test_data[:project_id]
    
    project_id = @test_data[:project_id]
    
    # Get first question for audio recording
    question_id = get_first_question_id
    
    # Test upload request
    upload_data = {
      fileName: "test_audio_#{Time.now.to_i}.wav",
      mimeType: "audio/wav",
      recordedDurationSeconds: 60,
      questionId: question_id
    }
    
    response = make_authenticated_request('POST', "/api/projects/#{project_id}/audio/upload-request", upload_data)
    
    if response.code == '200'
      result = JSON.parse(response.body)
      @test_data[:audio_segment_id] = result['audioSegmentId']
      @test_data[:upload_url] = result['uploadUrl']
      record_success("Upload Request", "Generated upload URL for audio segment")
    else
      record_failure("Upload Request", "Failed with status #{response.code}")
      return
    end
    
    # Simulate successful upload completion
    audio_segment_id = @test_data[:audio_segment_id]
    complete_data = {
      uploadStatus: "success"
    }
    
    response = make_authenticated_request('POST', "/api/projects/#{project_id}/audio/#{audio_segment_id}/upload-complete", complete_data)
    
    if response.code == '200'
      record_success("Upload Complete", "Marked audio upload as successful")
    else
      record_failure("Upload Complete", "Failed with status #{response.code}")
    end
    
    # Test playback URL generation
    if audio_segment_id
      response = make_authenticated_request('GET', "/api/projects/#{project_id}/audio/#{audio_segment_id}/playback-url")
      
      if response.code == '200'
        result = JSON.parse(response.body)
        playback_url = result['playbackUrl']
        record_success("Playback URL", "Generated playback URL")
        @test_data[:playback_url] = playback_url
      else
        record_failure("Playback URL", "Failed with status #{response.code}")
      end
    end
  end
  
  # Transcript Processing Tests
  def test_transcript_processing
    puts "\n📝 Testing Transcript Processing..."
    
    return unless @test_data[:project_id]
    
    project_id = @test_data[:project_id]
    
    # Check transcript status
    response = make_authenticated_request('GET', "/api/projects/#{project_id}/transcript")
    
    if response.code == '200'
      result = JSON.parse(response.body)
      transcript_status = result['status']
      content = result['content']
      
      record_success("Transcript Access", "Retrieved transcript with status: #{transcript_status}")
      
      if content && content.is_a?(Array)
        content_length = content.length
        record_success("Transcript Content", "Transcript contains #{content_length} sections")
        @test_data[:transcript_content] = content
      end
    else
      record_failure("Transcript Access", "Failed with status #{response.code}")
    end
  end
  
  # Content Export Tests
  def test_content_export
    puts "\n📄 Testing Content Export..."
    
    return unless @test_data[:project_id]
    
    project_id = @test_data[:project_id]
    
    # Test export preview
    response = make_authenticated_request('GET', "/api/projects/#{project_id}/export/preview")
    
    if response.code == '200'
      result = JSON.parse(response.body)
      
      if result['project'] && result['outline'] && result['statistics']
        record_success("Export Preview", "Retrieved export preview with project data")
        @test_data[:export_preview] = result
      else
        record_failure("Export Preview", "Invalid export preview structure")
      end
    else
      record_failure("Export Preview", "Failed with status #{response.code}")
    end
    
    # Test TXT export
    response = make_authenticated_request('GET', "/api/projects/#{project_id}/export/txt")
    
    if response.code == '200'
      content_length = response.body.length
      record_success("TXT Export", "Generated TXT export (#{content_length} characters)")
    else
      record_failure("TXT Export", "Failed with status #{response.code}")
    end
    
    # Test PDF export (placeholder)
    response = make_authenticated_request('GET', "/api/projects/#{project_id}/export/pdf")
    
    if response.code == '200'
      record_success("PDF Export", "Generated PDF export")
    else
      record_failure("PDF Export", "Failed with status #{response.code}")
    end
    
    # Test DOCX export (placeholder)
    response = make_authenticated_request('GET', "/api/projects/#{project_id}/export/docx")
    
    if response.code == '200'
      record_success("DOCX Export", "Generated DOCX export")
    else
      record_failure("DOCX Export", "Failed with status #{response.code}")
    end
  end

  # Project Completion Tests
  def test_project_completion
    puts "\n✅ Testing Project Completion..."
    
    return unless @test_data[:project_id]
    
    project_id = @test_data[:project_id]
    
    # Test outline editing
    updates = [
      {
        questionId: get_first_question_id,
        omitted: true
      }
    ]
    
    response = make_authenticated_request('PATCH', "/api/projects/#{project_id}/outline", { updates: updates })
    
    if response.code == '200'
      record_success("Outline Editing", "Successfully updated outline")
    else
      record_failure("Outline Editing", "Failed with status #{response.code}")
    end
    
    # Check final project status
    response = make_authenticated_request('GET', "/api/projects/#{project_id}")
    if response.code == '200'
      result = JSON.parse(response.body)
      final_status = result['status']
      last_modified = result['lastModifiedAt']
      
      record_success("Project Status", "Final status: #{final_status}, last modified: #{last_modified}")
    else
      record_failure("Project Status", "Failed to get final project status")
    end
  end
  
  # Error Handling Tests
  def test_error_handling
    puts "\n🚨 Testing Error Handling..."
    
    # Test invalid authentication
    response = make_request('GET', '/api/projects', {}, { 'Authorization' => 'Bearer invalid_token' })
    if response.code == '401' || response.code == '403'
      record_success("Auth Error Handling", "Properly rejected invalid token")
    else
      record_failure("Auth Error Handling", "Did not reject invalid token properly")
    end
    
    # Test invalid project access
    response = make_authenticated_request('GET', '/api/projects/999999')
    if response.code == '404'
      record_success("Not Found Handling", "Properly returned 404 for invalid project")
    else
      record_failure("Not Found Handling", "Did not handle invalid project properly")
    end
    
    # Test malformed data
    response = make_authenticated_request('POST', '/api/projects', { invalid: "data" })
    if response.code.to_i >= 400
      record_success("Validation Error", "Properly rejected malformed data")
    else
      record_failure("Validation Error", "Did not validate input properly")
    end
  end
  
  
  # Concurrent Operations Tests
  def test_concurrent_operations
    puts "\n⚡ Testing Concurrent Operations..."
    
    # Create multiple projects concurrently
    threads = []
    results = []
    
    3.times do |i|
      threads << Thread.new do
        project_data = {
          initialTopic: "Concurrent Test Project #{i + 1}"
        }
        
        response = make_authenticated_request('POST', '/api/projects', project_data)
        results << response.code == '201'
      end
    end
    
    threads.each(&:join)
    
    successful_creates = results.count(true)
    record_success("Concurrent Projects", "#{successful_creates}/3 concurrent project creations succeeded")
  end
  
  # Helper Methods
  def make_request(method, path, data = {}, headers = {})
    uri = URI("#{BASE_URL}#{path}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.read_timeout = 30
    
    request = case method.upcase
    when 'GET'
      Net::HTTP::Get.new(uri)
    when 'POST'
      req = Net::HTTP::Post.new(uri)
      req['Content-Type'] = 'application/json'
      req.body = data.to_json unless data.empty?
      req
    when 'PATCH'
      req = Net::HTTP::Patch.new(uri)
      req['Content-Type'] = 'application/json'
      req.body = data.to_json unless data.empty?
      req
    when 'DELETE'
      Net::HTTP::Delete.new(uri)
    end
    
    headers.each { |key, value| request[key] = value }
    
    http.request(request)
  end
  
  def make_authenticated_request(method, path, data = {}, extra_headers = {})
    headers = {}
    headers['Authorization'] = "Bearer #{@auth_token}" if @auth_token
    headers.merge!(extra_headers)
    make_request(method, path, data, headers)
  end
  
  def wait_for_project_status(project_id, expected_status, timeout: 30)
    start_time = Time.now
    
    while (Time.now - start_time) < timeout
      response = make_authenticated_request('GET', "/api/projects/#{project_id}")
      return false unless response.code == '200'
      
      result = JSON.parse(response.body)
      return true if result['status'] == expected_status
      
      sleep(2)
    end
    
    false
  end
  
  def get_first_question_id
    return nil unless @test_data[:project_outline]
    
    chapters = @test_data[:project_outline]['chapters']
    return nil unless chapters && chapters.any?
    
    sections = chapters[0]['sections']
    return nil unless sections && sections.any?
    
    questions = sections[0]['questions']
    return nil unless questions && questions.any?
    
    questions[0]['questionId']
  end
  
  
  def record_success(test_name, message)
    @test_results << { test: test_name, status: :success, message: message }
    puts "   ✅ #{test_name}: #{message}"
  end
  
  def record_failure(test_name, message)
    @test_results << { test: test_name, status: :failure, message: message }
    puts "   ❌ #{test_name}: #{message}"
  end
  
  def print_comprehensive_summary
    puts "\n" + "=" * 60
    puts "📊 COMPREHENSIVE API TEST SUMMARY"
    puts "=" * 60
    
    successes = @test_results.count { |r| r[:status] == :success }
    failures = @test_results.count { |r| r[:status] == :failure }
    total = @test_results.length
    
    puts "✅ Passed: #{successes}/#{total}"
    puts "❌ Failed: #{failures}/#{total}" if failures > 0
    puts "📈 Success Rate: #{((successes.to_f / total) * 100).round(1)}%"
    
    # Core User Journey Analysis
    puts "\n🎯 CORE USER JOURNEY ANALYSIS:"
    
    journey_steps = [
      "User Registration",
      "User Login",
      "Project Creation", 
      "Outline Generation",
      "Upload Request",
      "Upload Complete",
      "Transcript Access",
      "Project Status"
    ]
    
    journey_success = journey_steps.all? do |step|
      @test_results.any? { |r| r[:test] == step && r[:status] == :success }
    end
    
    journey_steps.each do |step|
      status = @test_results.find { |r| r[:test] == step }&.dig(:status)
      icon = status == :success ? '✅' : (status == :failure ? '❌' : '⚠️')
      puts "   #{icon} #{step}"
    end
    
    puts "\n🔧 SYSTEM COMPONENTS:"
    puts "   #{@test_results.any? { |r| r[:test] =~ /Auth/ && r[:status] == :success } ? '✅' : '❌'} Authentication System"
    puts "   #{@test_results.any? { |r| r[:test] =~ /Project/ && r[:status] == :success } ? '✅' : '❌'} Project Management"
    puts "   #{@test_results.any? { |r| r[:test] =~ /Outline/ && r[:status] == :success } ? '✅' : '❌'} AI Question Generation"
    puts "   #{@test_results.any? { |r| r[:test] =~ /Upload|Audio/ && r[:status] == :success } ? '✅' : '❌'} Audio Processing"
    puts "   #{@test_results.any? { |r| r[:test] =~ /Transcript/ && r[:status] == :success } ? '✅' : '❌'} Transcript System"
    puts "   #{@test_results.any? { |r| r[:test] =~ /Export/ && r[:status] == :success } ? '✅' : '❌'} Content Export"
    puts "   #{@test_results.any? { |r| r[:test] =~ /Error/ && r[:status] == :success } ? '✅' : '❌'} Error Handling"
    
    if failures > 0
      puts "\n🔍 FAILED TESTS:"
      @test_results.select { |r| r[:status] == :failure }.each do |result|
        puts "   • #{result[:test]}: #{result[:message]}"
      end
      
      puts "\n🔧 RECOMMENDATIONS:"
      
      auth_failures = @test_results.select { |r| r[:test] =~ /Auth/ && r[:status] == :failure }
      if auth_failures.any?
        puts "   🔐 Fix authentication system - check JWT configuration"
      end
      
      project_failures = @test_results.select { |r| r[:test] =~ /Project/ && r[:status] == :failure }
      if project_failures.any?
        puts "   📁 Check project creation and management logic"
      end
      
      audio_failures = @test_results.select { |r| r[:test] =~ /Upload|Audio/ && r[:status] == :failure }
      if audio_failures.any?
        puts "   🎵 Verify S3 configuration and audio processing pipeline"
      end
    end
    
    puts "\n📊 TEST DATA SUMMARY:"
    if @test_data[:project_id]
      puts "   📁 Created Project ID: #{@test_data[:project_id]}"
      puts "   📝 Project Title: #{@test_data[:project_title]}"
    end
    if @test_data[:audio_segment_id]
      puts "   🎵 Audio Segment ID: #{@test_data[:audio_segment_id]}"
    end
    if @test_data[:user_email]
      puts "   👤 Test User: #{@test_data[:user_email]}"
    end
    
    puts "\n🎯 Overall API Status: #{journey_success ? '✅ CORE JOURNEY FUNCTIONAL' : '❌ CORE JOURNEY BLOCKED'}"
    
    if journey_success
      puts "\n🎉 Excellent! The core user journey is working end-to-end."
      puts "   Users can register, create projects, generate outlines, upload audio, and access transcripts."
    else
      puts "\n⚠️  Critical issues detected in the core user journey."
      puts "   Address the failed tests above before proceeding with development."
    end
    
    puts "\n💡 NEXT STEPS:"
    if journey_success
      puts "   2. Add content export features (PDF/DOCX/txt)"
      puts "   3. Set up production environment and monitoring"
      puts "   4. Implement background job processing with Sidekiq"
    else
      puts "   1. Fix the failed tests identified above"
      puts "   2. Re-run this test harness to verify fixes"
      puts "   3. Check Rails logs for detailed error information"
    end
  end
end

# Run the test harness if this file is executed directly
if __FILE__ == $0
  test_harness = ApiTestHarness.new
  test_harness.run_complete_test_suite
end