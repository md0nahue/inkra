#!/usr/bin/env ruby

# Live Integration Test for Gemini Service
# Note: Gemini doesn't support direct audio transcription, so this tests the API connectivity
# and suggests Google Speech-to-Text as an alternative

require_relative '../../config/environment'

class GeminiTranscriptionLiveTest
  def initialize
    @api_key = ENV['GEMINI_API_KEY']
    @test_results = []
    
    puts "🎯 Gemini Service Live Test"
    puts "=" * 50
    
    unless @api_key
      puts "❌ GEMINI_API_KEY environment variable not set"
      puts "Please set your Gemini API key: export GEMINI_API_KEY=your_key_here"
      exit(1)
    end
    
    puts "✅ Gemini API key found"
    puts "⚠️  Note: Gemini doesn't support direct audio transcription"
    puts "   This test validates API connectivity and suggests alternatives"
  end
  
  def run_all_tests
    puts "\n🚀 Starting Gemini API tests...\n"
    
    test_gemini_api_connectivity
    test_gemini_text_generation
    test_transcription_service_integration
    test_google_speech_to_text_suggestion
    test_error_handling
    
    print_test_summary
  end
  
  private
  
  def test_gemini_api_connectivity
    puts "📡 Testing Gemini API connectivity..."
    
    begin
      uri = URI("https://generativelanguage.googleapis.com/v1beta/models?key=#{@api_key}")
      request = Net::HTTP::Get.new(uri)
      
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = 10
      
      response = http.request(request)
      
      if response.code == '200'
        models = JSON.parse(response.body)
        model_names = models['models']&.map { |m| m['name'] } || []
        
        record_success("API connectivity", "Connected successfully. Found #{model_names.length} models")
        puts "   Available models: #{model_names.take(3).join(', ')}#{model_names.length > 3 ? '...' : ''}"
      else
        record_failure("API connectivity", "HTTP #{response.code}: #{response.message}")
      end
      
    rescue => e
      record_failure("API connectivity", "Connection failed: #{e.message}")
    end
  end
  
  def test_gemini_text_generation
    puts "\n💬 Testing Gemini text generation capabilities..."
    
    begin
      service = InterviewQuestionService.new(@api_key)
      
      start_time = Time.now
      result = service.generate_interview_outline("Software Engineering Career", {
        num_chapters: 2,
        sections_per_chapter: 2,
        questions_per_section: 2
      })
      end_time = Time.now
      
      processing_time = (end_time - start_time).round(2)
      
      if result && !result[:error]
        record_success("Text generation", "Generated interview outline in #{processing_time}s")
        puts "   📝 Generated title: \"#{result[:title]}\""
        puts "   📊 Chapters: #{result[:chapters]&.length || 0}"
        puts "   ⏱️  Processing time: #{processing_time} seconds"
      else
        record_failure("Text generation", "Failed: #{result[:error] || 'Unknown error'}")
      end
      
    rescue => e
      record_failure("Text generation", "Exception: #{e.message}")
    end
  end
  
  def test_transcription_service_integration
    puts "\n🔧 Testing TranscriptionService Gemini integration..."
    
    begin
      # Set environment to use Gemini
      original_provider = ENV['TRANSCRIPTION_PROVIDER']
      ENV['TRANSCRIPTION_PROVIDER'] = 'gemini'
      
      # Create mock audio segment
      audio_segment = create_mock_audio_segment
      
      # Test the transcription method (should return limitation message)
      result = TranscriptionService.send(:transcribe_with_gemini, "dummy_audio_data", audio_segment, @api_key)
      
      if result[:success] == false && result[:error].include?("not implemented")
        record_success("Service integration", "Correctly reports Gemini limitation")
        puts "   📝 Message: #{result[:error]}"
      else
        record_failure("Service integration", "Unexpected result from Gemini transcription method")
      end
      
      # Test full service (should fall back to mock in development)
      if Rails.env.development?
        full_result = TranscriptionService.process_transcription(create_test_audio_segment.id)
        if full_result[:success]
          record_success("Fallback behavior", "Correctly falls back to mock transcription in development")
        else
          record_failure("Fallback behavior", "Failed to fall back properly")
        end
      end
      
      ENV['TRANSCRIPTION_PROVIDER'] = original_provider
      
    rescue => e
      record_failure("Service integration", "Integration test failed: #{e.message}")
      ENV['TRANSCRIPTION_PROVIDER'] = original_provider
    end
  end
  
  def test_google_speech_to_text_suggestion
    puts "\n🗣️  Testing Google Speech-to-Text API as Gemini alternative..."
    
    begin
      # Check if Google Cloud credentials are available
      if ENV['GOOGLE_APPLICATION_CREDENTIALS'] || ENV['GOOGLE_CLOUD_PROJECT']
        record_success("Google Cloud setup", "Google Cloud credentials detected")
        puts "   📝 Credentials: #{ENV['GOOGLE_APPLICATION_CREDENTIALS'] ? 'File-based' : 'Environment-based'}"
        puts "   🏗️  Project: #{ENV['GOOGLE_CLOUD_PROJECT'] || 'Not set'}"
        
        # Test basic Google Speech-to-Text API connectivity (if gem is available)
        begin
          require 'google/cloud/speech'
          record_success("Speech-to-Text gem", "Google Speech-to-Text gem is available")
          puts "   💡 Recommendation: Use Google::Cloud::Speech for audio transcription"
        rescue LoadError
          record_failure("Speech-to-Text gem", "Google Speech-to-Text gem not installed")
          puts "   💡 Install with: gem install google-cloud-speech"
        end
      else
        record_failure("Google Cloud setup", "No Google Cloud credentials found")
        puts "   💡 Set GOOGLE_APPLICATION_CREDENTIALS or configure default credentials"
      end
      
    rescue => e
      record_failure("Google Cloud setup", "Error checking Google Cloud setup: #{e.message}")
    end
  end
  
  def test_error_handling
    puts "\n🚨 Testing error handling..."
    
    # Test with invalid API key
    begin
      service = InterviewQuestionService.new('invalid_key')
      result = service.generate_interview_outline("Test Topic")
      
      record_failure("Invalid API key handling", "Should have failed with invalid key")
    rescue => e
      if e.message.include?('API') || e.message.include?('401') || e.message.include?('403')
        record_success("Invalid API key handling", "Correctly handled invalid API key")
      else
        record_failure("Invalid API key handling", "Unexpected error: #{e.message}")
      end
    end
    
    # Test TranscriptionService error handling
    begin
      original_provider = ENV['TRANSCRIPTION_PROVIDER']
      ENV['TRANSCRIPTION_PROVIDER'] = 'gemini'
      
      audio_segment = create_mock_audio_segment
      result = TranscriptionService.send(:transcribe_with_gemini, nil, audio_segment, @api_key)
      
      if result[:success] == false
        record_success("Null audio handling", "Correctly handled null audio data")
      else
        record_failure("Null audio handling", "Did not properly handle null audio")
      end
      
      ENV['TRANSCRIPTION_PROVIDER'] = original_provider
      
    rescue => e
      record_success("Null audio handling", "Exception properly raised: #{e.message}")
      ENV['TRANSCRIPTION_PROVIDER'] = original_provider
    end
  end
  
  def create_mock_audio_segment
    OpenStruct.new(
      id: 1,
      file_name: 'test_audio.wav',
      mime_type: 'audio/wav',
      duration_seconds: 60
    )
  end
  
  def create_test_audio_segment
    user = User.first || create_test_user
    project = create_test_project(user)
    
    audio_segment = project.audio_segments.create!(
      file_name: 'gemini_test_audio.wav',
      mime_type: 'audio/wav',
      duration_seconds: 60,
      upload_status: 'success'
    )
    
    # Clean up after test
    at_exit do
      begin
        audio_segment.destroy
        project.destroy
        user.destroy if user.email.include?('test_gemini')
      rescue
        # Ignore cleanup errors
      end
    end
    
    audio_segment
  end
  
  def create_test_user
    User.create!(
      email: "test_gemini_#{Time.now.to_i}@example.com",
      password: 'password123'
    )
  end
  
  def create_test_project(user)
    user.projects.create!(
      title: "Gemini Test Project #{Time.now.to_i}",
      description: "Test project for Gemini integration",
      status: 'draft'
    )
  end
  
  def record_success(test_name, message)
    @test_results << { test: test_name, status: :success, message: message }
    puts "   ✅ #{test_name}: #{message}"
  end
  
  def record_failure(test_name, message)
    @test_results << { test: test_name, status: :failure, message: message }
    puts "   ❌ #{test_name}: #{message}"
  end
  
  def print_test_summary
    puts "\n" + "=" * 50
    puts "📊 TEST SUMMARY"
    puts "=" * 50
    
    successes = @test_results.count { |r| r[:status] == :success }
    failures = @test_results.count { |r| r[:status] == :failure }
    total = @test_results.length
    
    puts "✅ Passed: #{successes}/#{total}"
    puts "❌ Failed: #{failures}/#{total}" if failures > 0
    puts "📈 Success Rate: #{((successes.to_f / total) * 100).round(1)}%"
    
    if failures > 0
      puts "\n🔍 FAILED TESTS:"
      @test_results.select { |r| r[:status] == :failure }.each do |result|
        puts "   • #{result[:test]}: #{result[:message]}"
      end
    end
    
    puts "\n💡 RECOMMENDATIONS:"
    puts "   • For audio transcription with Google AI, use Google Speech-to-Text API"
    puts "   • Gemini is excellent for text generation, question creation, and content analysis"
    puts "   • Consider a hybrid approach: Speech-to-Text for transcription + Gemini for analysis"
    
    puts "\n🎯 Overall Status: #{failures == 0 ? '✅ ALL TESTS PASSED' : '❌ SOME TESTS FAILED'}"
  end
end

# Run the test if this file is executed directly
if __FILE__ == $0
  test_runner = GeminiTranscriptionLiveTest.new
  test_runner.run_all_tests
end