#!/usr/bin/env ruby

# Live Integration Test for Groq Whisper Transcription Service
# This script tests the actual Groq API with real audio files

require_relative '../../config/environment'
require 'tempfile'
require 'base64'

class GroqTranscriptionLiveTest
  SAMPLE_AUDIO_URL = 'https://www2.cs.uic.edu/~i101/SoundFiles/BabyElephantWalk60.wav'
  
  def initialize
    @api_key = ENV['GROQ_API_KEY']
    @test_results = []
    
    puts "🎯 Groq Whisper Transcription Live Test"
    puts "=" * 50
    
    unless @api_key
      puts "❌ GROQ_API_KEY environment variable not set"
      puts "Please set your Groq API key: export GROQ_API_KEY=your_key_here"
      exit(1)
    end
    
    puts "✅ Groq API key found"
  end
  
  def run_all_tests
    puts "\n🚀 Starting comprehensive Groq transcription tests...\n"
    
    test_api_connectivity
    test_audio_download
    test_transcription_with_real_audio
    test_transcription_service_integration
    test_error_handling
    
    print_test_summary
  end
  
  private
  
  def test_api_connectivity
    puts "📡 Testing Groq API connectivity..."
    
    begin
      uri = URI('https://api.groq.com/openai/v1/models')
      request = Net::HTTP::Get.new(uri)
      request['Authorization'] = "Bearer #{@api_key}"
      
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = 10
      
      response = http.request(request)
      
      if response.code == '200'
        models = JSON.parse(response.body)
        whisper_models = models['data'].select { |m| m['id'].include?('whisper') }
        
        if whisper_models.any?
          record_success("API connectivity", "Connected successfully. Found #{whisper_models.length} Whisper models")
          puts "   Available Whisper models: #{whisper_models.map { |m| m['id'] }.join(', ')}"
        else
          record_failure("API connectivity", "No Whisper models found in response")
        end
      else
        record_failure("API connectivity", "HTTP #{response.code}: #{response.message}")
      end
      
    rescue => e
      record_failure("API connectivity", "Connection failed: #{e.message}")
    end
  end
  
  def test_audio_download
    puts "\n🔊 Testing audio file download..."
    
    begin
      uri = URI(SAMPLE_AUDIO_URL)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == 'https')
      
      response = http.get(uri.path)
      
      if response.code == '200' && response.body.length > 0
        @test_audio_data = response.body
        record_success("Audio download", "Downloaded #{response.body.length} bytes")
        puts "   Content-Type: #{response['content-type']}"
        puts "   File size: #{format_bytes(response.body.length)}"
      else
        record_failure("Audio download", "Failed to download audio: HTTP #{response.code}")
      end
      
    rescue => e
      record_failure("Audio download", "Download error: #{e.message}")
    end
  end
  
  def test_transcription_with_real_audio
    puts "\n🎤 Testing Groq Whisper transcription with real audio..."
    
    return unless @test_audio_data
    
    begin
      start_time = Time.now
      
      # Test with the TranscriptionService's Groq method
      audio_segment = create_mock_audio_segment
      result = TranscriptionService.send(:transcribe_with_groq, @test_audio_data, audio_segment, @api_key)
      
      end_time = Time.now
      processing_time = (end_time - start_time).round(2)
      
      if result[:success]
        record_success("Groq transcription", "Transcribed successfully in #{processing_time}s")
        puts "   📝 Transcription: \"#{result[:text].strip}\""
        puts "   ⏱️  Processing time: #{processing_time} seconds"
        puts "   📊 Text length: #{result[:text].length} characters"
        
        # Test transcription quality
        if result[:text].length > 10
          record_success("Transcription quality", "Generated meaningful text (#{result[:text].length} chars)")
        else
          record_failure("Transcription quality", "Text too short, may indicate poor transcription")
        end
      else
        record_failure("Groq transcription", "Failed: #{result[:error]}")
      end
      
    rescue => e
      record_failure("Groq transcription", "Exception: #{e.message}")
    end
  end
  
  def test_transcription_service_integration
    puts "\n🔧 Testing TranscriptionService integration..."
    
    begin
      # Create test project and audio segment
      user = User.first || create_test_user
      project = create_test_project(user)
      audio_segment = create_test_audio_segment(project)
      
      # Set environment to use Groq
      original_provider = ENV['TRANSCRIPTION_PROVIDER']
      ENV['TRANSCRIPTION_PROVIDER'] = 'groq'
      
      # Test the full service integration
      start_time = Time.now
      result = TranscriptionService.process_transcription(audio_segment.id)
      end_time = Time.now
      
      processing_time = (end_time - start_time).round(2)
      
      if result[:success]
        audio_segment.reload
        record_success("Service integration", "Full service test passed in #{processing_time}s")
        puts "   📝 Final transcription: \"#{audio_segment.transcription_text}\""
        puts "   📊 Audio segment status: #{audio_segment.upload_status}"
      else
        record_failure("Service integration", "Service test failed: #{result[:error]}")
      end
      
      # Clean up
      audio_segment.destroy
      project.destroy
      ENV['TRANSCRIPTION_PROVIDER'] = original_provider
      
    rescue => e
      record_failure("Service integration", "Integration test failed: #{e.message}")
      ENV['TRANSCRIPTION_PROVIDER'] = original_provider
    end
  end
  
  def test_error_handling
    puts "\n🚨 Testing error handling..."
    
    # Test with invalid API key
    begin
      audio_segment = create_mock_audio_segment
      result = TranscriptionService.send(:transcribe_with_groq, @test_audio_data, audio_segment, 'invalid_key')
      
      if result[:success] == false && result[:error].include?('401')
        record_success("Invalid API key handling", "Correctly handled invalid API key")
      else
        record_failure("Invalid API key handling", "Did not properly handle invalid API key")
      end
    rescue => e
      record_success("Invalid API key handling", "Exception properly raised: #{e.message}")
    end
    
    # Test with malformed audio data
    begin
      audio_segment = create_mock_audio_segment
      result = TranscriptionService.send(:transcribe_with_groq, "invalid_audio_data", audio_segment, @api_key)
      
      if result[:success] == false
        record_success("Invalid audio handling", "Correctly handled invalid audio data")
      else
        record_failure("Invalid audio handling", "Did not properly handle invalid audio")
      end
    rescue => e
      record_success("Invalid audio handling", "Exception properly raised: #{e.message}")
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
  
  def create_test_user
    User.create!(
      email: "test_groq_#{Time.now.to_i}@example.com",
      password: 'password123'
    )
  end
  
  def create_test_project(user)
    user.projects.create!(
      title: "Groq Test Project #{Time.now.to_i}",
      description: "Test project for Groq transcription",
      status: 'draft'
    )
  end
  
  def create_test_audio_segment(project)
    project.audio_segments.create!(
      file_name: 'groq_test_audio.wav',
      mime_type: 'audio/wav',
      duration_seconds: 60,
      upload_status: 'success'
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
    
    puts "\n🎯 Overall Status: #{failures == 0 ? '✅ ALL TESTS PASSED' : '❌ SOME TESTS FAILED'}"
  end
  
  def format_bytes(bytes)
    return "#{bytes} B" if bytes < 1024
    return "#{(bytes / 1024.0).round(1)} KB" if bytes < 1024 * 1024
    "#{(bytes / (1024.0 * 1024)).round(1)} MB"
  end
end

# Run the test if this file is executed directly
if __FILE__ == $0
  test_runner = GroqTranscriptionLiveTest.new
  test_runner.run_all_tests
end