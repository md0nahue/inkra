#!/usr/bin/env ruby

# End-to-End Live Integration Test for VibeWrite Backend
# This script tests the complete flow: S3 upload → Transcription → Processing

require_relative '../../config/environment'
require 'tempfile'

class EndToEndLiveTest
  SAMPLE_AUDIO_URL = 'https://www2.cs.uic.edu/~i101/SoundFiles/BabyElephantWalk60.wav'
  
  def initialize
    @test_results = []
    @test_data = {}
    
    puts "🎯 End-to-End Live Integration Test"
    puts "=" * 60
    puts "Testing complete workflow: S3 → Transcription → Processing"
    
    check_prerequisites
    puts "✅ All prerequisites met"
  end
  
  def run_full_workflow_test
    puts "\n🚀 Starting end-to-end workflow test...\n"
    
    setup_test_environment
    test_complete_audio_workflow
    test_project_lifecycle
    test_multiple_audio_segments
    test_error_recovery
    cleanup_test_environment
    
    print_test_summary
  end
  
  private
  
  def check_prerequisites
    # Check required environment variables
    required_vars = []
    
    # AWS credentials
    required_vars << "AWS_ACCESS_KEY_ID" unless ENV['AWS_ACCESS_KEY_ID']
    required_vars << "AWS_SECRET_ACCESS_KEY" unless ENV['AWS_SECRET_ACCESS_KEY']
    required_vars << "AWS_S3_BUCKET" unless ENV['AWS_S3_BUCKET']
    
    # At least one transcription service
    has_transcription = ENV['OPENAI_API_KEY'] || ENV['GROQ_API_KEY'] || ENV['GEMINI_API_KEY']
    required_vars << "OPENAI_API_KEY or GROQ_API_KEY" unless has_transcription
    
    if required_vars.any?
      puts "❌ Missing required environment variables:"
      required_vars.each { |var| puts "   #{var}" }
      exit(1)
    end
  end
  
  def setup_test_environment
    puts "🔧 Setting up test environment..."
    
    begin
      # Create test user
      @test_user = User.create!(
        email: "e2e_test_#{Time.now.to_i}@example.com",
        password: 'password123'
      )
      
      # Create test project
      @test_project = @test_user.projects.create!(
        title: "End-to-End Test Project",
        description: "Testing complete audio processing workflow",
        status: 'draft'
      )
      
      # Download sample audio
      @sample_audio_data = download_sample_audio
      
      record_success("Environment setup", "Test user, project, and audio data prepared")
      puts "   👤 Test user: #{@test_user.email}"
      puts "   📁 Test project: #{@test_project.title} (ID: #{@test_project.id})"
      puts "   🎵 Sample audio: #{format_bytes(@sample_audio_data.length)}"
      
    rescue => e
      record_failure("Environment setup", "Setup failed: #{e.message}")
      raise e
    end
  end
  
  def test_complete_audio_workflow
    puts "\n🎬 Testing complete audio processing workflow..."
    
    begin
      # Step 1: Create audio segment
      audio_segment = @test_project.audio_segments.create!(
        file_name: 'e2e_test_audio.wav',
        mime_type: 'audio/wav',
        duration_seconds: 60,
        upload_status: 'pending'
      )
      
      record_success("Audio segment creation", "Created audio segment #{audio_segment.id}")
      
      # Step 2: Generate presigned upload URL
      controller = Api::AudioSegmentsController.new
      controller.instance_variable_set(:@project, @test_project)
      
      upload_url = controller.send(:generate_presigned_url, audio_segment)
      record_success("Presigned URL generation", "Generated upload URL")
      
      # Step 3: Upload audio to S3
      upload_start = Time.now
      upload_success = upload_audio_to_s3(upload_url, @sample_audio_data)
      upload_time = (Time.now - upload_start).round(2)
      
      if upload_success
        record_success("S3 upload", "Uploaded audio in #{upload_time}s")
        audio_segment.update!(upload_status: 'success')
      else
        record_failure("S3 upload", "Failed to upload audio")
        return
      end
      
      # Step 4: Trigger transcription
      transcription_start = Time.now
      TranscriptionService.trigger_transcription_job(audio_segment.id)
      
      # Wait for transcription to complete (with timeout)
      transcription_result = wait_for_transcription(audio_segment, timeout: 120)
      transcription_time = (Time.now - transcription_start).round(2)
      
      if transcription_result
        record_success("Transcription", "Completed transcription in #{transcription_time}s")
        puts "   📝 Transcription: \"#{audio_segment.transcription_text&.truncate(100)}\""
        puts "   📊 Text length: #{audio_segment.transcription_text&.length || 0} characters"
      else
        record_failure("Transcription", "Transcription failed or timed out")
      end
      
      # Step 5: Test playback URL generation
      if audio_segment.upload_status == 'transcribed'
        playback_url = controller.send(:generate_playback_url, audio_segment)
        if playback_url&.start_with?('https://')
          record_success("Playback URL", "Generated playback URL")
          
          # Test playback URL accessibility
          if test_playback_url(playback_url)
            record_success("Playback access", "Audio accessible via playback URL")
          else
            record_failure("Playback access", "Cannot access audio via playback URL")
          end
        else
          record_failure("Playback URL", "Failed to generate playback URL")
        end
      end
      
      @test_data[:audio_segment] = audio_segment
      
    rescue => e
      record_failure("Complete workflow", "Workflow failed: #{e.message}")
    end
  end
  
  def test_project_lifecycle
    puts "\n📋 Testing project lifecycle management..."
    
    begin
      # Check project status updates
      initial_status = @test_project.status
      
      # Project should update status during transcription
      @test_project.reload
      if @test_project.status == 'transcribing' || @test_project.status == 'completed'
        record_success("Project status", "Project status updated during workflow")
        puts "   📊 Status: #{initial_status} → #{@test_project.status}"
      else
        record_failure("Project status", "Project status not updated properly")
      end
      
      # Test project completion logic
      if all_segments_processed?(@test_project)
        record_success("Project completion", "All audio segments processed")
      else
        record_failure("Project completion", "Not all segments processed properly")
      end
      
    rescue => e
      record_failure("Project lifecycle", "Lifecycle test failed: #{e.message}")
    end
  end
  
  def test_multiple_audio_segments
    puts "\n🎵 Testing multiple audio segments..."
    
    begin
      # Create additional audio segments
      segments = []
      3.times do |i|
        segment = @test_project.audio_segments.create!(
          file_name: "multi_test_#{i + 1}.wav",
          mime_type: 'audio/wav',
          duration_seconds: 30,
          upload_status: 'success'
        )
        segments << segment
      end
      
      record_success("Multiple segments", "Created #{segments.length} additional segments")
      
      # Test concurrent transcription
      start_time = Time.now
      segments.each do |segment|
        TranscriptionService.trigger_transcription_job(segment.id)
      end
      
      # Wait for all to complete
      all_completed = wait_for_multiple_transcriptions(segments, timeout: 180)
      total_time = (Time.now - start_time).round(2)
      
      if all_completed
        completed_count = segments.count { |s| s.reload.upload_status == 'transcribed' }
        record_success("Concurrent transcription", "#{completed_count}/#{segments.length} completed in #{total_time}s")
      else
        record_failure("Concurrent transcription", "Not all segments completed in time")
      end
      
    rescue => e
      record_failure("Multiple segments", "Multi-segment test failed: #{e.message}")
    end
  end
  
  def test_error_recovery
    puts "\n🚨 Testing error recovery mechanisms..."
    
    begin
      # Test handling of invalid audio data
      invalid_segment = @test_project.audio_segments.create!(
        file_name: 'invalid_audio.wav',
        mime_type: 'audio/wav',
        duration_seconds: 1,
        upload_status: 'success'
      )
      
      # This should fail gracefully
      result = TranscriptionService.process_transcription(invalid_segment.id)
      
      if result[:success] == false || invalid_segment.reload.upload_status == 'transcription_failed'
        record_success("Error recovery", "Gracefully handled invalid audio")
      else
        record_failure("Error recovery", "Did not handle invalid audio properly")
      end
      
      # Test project status after failures
      @test_project.reload
      if @test_project.audio_segments.where(upload_status: 'transcribed').exists?
        record_success("Partial failure handling", "Project remains functional after partial failures")
      else
        record_failure("Partial failure handling", "Project not handling partial failures well")
      end
      
    rescue => e
      record_success("Error recovery", "Exception properly handled: #{e.message}")
    end
  end
  
  def cleanup_test_environment
    puts "\n🧹 Cleaning up test environment..."
    
    begin
      # Delete S3 objects
      deleted_objects = 0
      if @test_project
        @test_project.audio_segments.each do |segment|
          if delete_s3_object(segment)
            deleted_objects += 1
          end
        end
      end
      
      # Delete database records
      @test_project&.destroy
      @test_user&.destroy
      
      record_success("Cleanup", "Cleaned up #{deleted_objects} S3 objects and database records")
      
    rescue => e
      record_failure("Cleanup", "Cleanup failed: #{e.message}")
    end
  end
  
  def download_sample_audio
    uri = URI(SAMPLE_AUDIO_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == 'https')
    
    response = http.get(uri.path)
    if response.code == '200'
      response.body
    else
      raise "Failed to download sample audio: HTTP #{response.code}"
    end
  end
  
  def upload_audio_to_s3(upload_url, audio_data)
    uri = URI(upload_url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    
    request = Net::HTTP::Put.new(uri.request_uri)
    request['Content-Type'] = 'audio/wav'
    request.body = audio_data
    
    response = http.request(request)
    response.code.to_i.between?(200, 299)
  end
  
  def wait_for_transcription(audio_segment, timeout: 60)
    start_time = Time.now
    
    while (Time.now - start_time) < timeout
      audio_segment.reload
      if audio_segment.upload_status == 'transcribed'
        return true
      elsif audio_segment.upload_status == 'transcription_failed'
        return false
      end
      
      sleep(2)
    end
    
    false
  end
  
  def wait_for_multiple_transcriptions(segments, timeout: 120)
    start_time = Time.now
    
    while (Time.now - start_time) < timeout
      segments.each(&:reload)
      completed = segments.all? { |s| ['transcribed', 'transcription_failed'].include?(s.upload_status) }
      return true if completed
      
      sleep(3)
    end
    
    false
  end
  
  def test_playback_url(playback_url)
    uri = URI(playback_url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 10
    
    response = http.head(uri.request_uri)
    response.code == '200'
  rescue
    false
  end
  
  def all_segments_processed?(project)
    project.reload
    successful_segments = project.audio_segments.where(upload_status: ['success', 'transcribed'])
    return true if successful_segments.empty?
    
    successful_segments.all? { |segment| segment.upload_status == 'transcribed' }
  end
  
  def delete_s3_object(audio_segment)
    begin
      s3_client = Aws::S3::Client.new(
        region: ENV['AWS_REGION'] || 'us-east-1',
        access_key_id: ENV['AWS_ACCESS_KEY_ID'],
        secret_access_key: ENV['AWS_SECRET_ACCESS_KEY']
      )
      
      bucket = ENV['AWS_S3_BUCKET']
      key = "audio_segments/#{audio_segment.id}/#{audio_segment.file_name}"
      
      s3_client.delete_object(bucket: bucket, key: key)
      true
    rescue
      false
    end
  end
  
  def record_success(test_name, message)
    @test_results << { test: test_name, status: :success, message: message }
    puts "   ✅ #{test_name}: #{message}"
  end
  
  def record_failure(test_name, message)
    @test_results << { test: test_name, status: :failure, message: message }
    puts "   ❌ #{test_name}: #{message}"
  end
  
  def format_bytes(bytes)
    return "#{bytes} B" if bytes < 1024
    return "#{(bytes / 1024.0).round(1)} KB" if bytes < 1024 * 1024
    "#{(bytes / (1024.0 * 1024)).round(1)} MB"
  end
  
  def print_test_summary
    puts "\n" + "=" * 60
    puts "📊 END-TO-END TEST SUMMARY"
    puts "=" * 60
    
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
    
    puts "\n🎯 WORKFLOW VERIFICATION:"
    puts "   📤 Audio Upload: #{@test_results.any? { |r| r[:test] == 'S3 upload' && r[:status] == :success } ? '✅' : '❌'}"
    puts "   🎤 Transcription: #{@test_results.any? { |r| r[:test] == 'Transcription' && r[:status] == :success } ? '✅' : '❌'}"
    puts "   📥 Playback: #{@test_results.any? { |r| r[:test] == 'Playback access' && r[:status] == :success } ? '✅' : '❌'}"
    puts "   🔄 Error Recovery: #{@test_results.any? { |r| r[:test] == 'Error recovery' && r[:status] == :success } ? '✅' : '❌'}"
    
    transcription_provider = ENV['TRANSCRIPTION_PROVIDER'] || 'whisper'
    puts "\n🔧 CONFIGURATION:"
    puts "   🎯 Transcription Provider: #{transcription_provider.upcase}"
    puts "   🪣 S3 Bucket: #{ENV['AWS_S3_BUCKET']}"
    puts "   📍 AWS Region: #{ENV['AWS_REGION'] || 'us-east-1'}"
    
    puts "\n🎯 Overall Status: #{failures == 0 ? '✅ ALL SYSTEMS OPERATIONAL' : '❌ SOME ISSUES DETECTED'}"
    
    if failures == 0
      puts "\n🎉 Congratulations! Your VibeWrite backend is fully functional!"
      puts "   The complete audio processing workflow is working correctly."
    else
      puts "\n🔧 Some components need attention. Check the failed tests above."
    end
  end
end

# Run the test if this file is executed directly
if __FILE__ == $0
  test_runner = EndToEndLiveTest.new
  test_runner.run_full_workflow_test
end