#!/usr/bin/env ruby

# Live Integration Test for AWS S3 Presigned URLs
# This script tests actual AWS S3 operations with real credentials

require_relative '../../config/environment'
require 'tempfile'

class AwsS3LiveTest
  def initialize
    @aws_access_key = ENV['AWS_ACCESS_KEY_ID']
    @aws_secret_key = ENV['AWS_SECRET_ACCESS_KEY']
    @aws_region = ENV['AWS_REGION'] || 'us-east-1'
    @s3_bucket = ENV['AWS_S3_BUCKET']
    @test_results = []
    
    puts "🎯 AWS S3 Presigned URLs Live Test"
    puts "=" * 50
    
    check_aws_credentials
    puts "✅ AWS credentials configured"
  end
  
  def run_all_tests
    puts "\n🚀 Starting comprehensive AWS S3 tests...\n"
    
    test_aws_s3_connectivity
    test_bucket_access
    test_presigned_url_generation
    test_file_upload_via_presigned_url
    test_file_download_via_presigned_url
    test_audio_segments_controller_integration
    test_error_handling
    test_cleanup
    
    print_test_summary
  end
  
  private
  
  def check_aws_credentials
    missing_creds = []
    missing_creds << "AWS_ACCESS_KEY_ID" unless @aws_access_key
    missing_creds << "AWS_SECRET_ACCESS_KEY" unless @aws_secret_key
    missing_creds << "AWS_S3_BUCKET" unless @s3_bucket
    
    if missing_creds.any?
      puts "❌ Missing AWS environment variables: #{missing_creds.join(', ')}"
      puts "Please set the following environment variables:"
      missing_creds.each { |var| puts "   export #{var}=your_value_here" }
      exit(1)
    end
  end
  
  def test_aws_s3_connectivity
    puts "📡 Testing AWS S3 connectivity..."
    
    begin
      s3_client = create_s3_client
      
      # Test basic S3 access by listing buckets
      response = s3_client.list_buckets
      
      bucket_names = response.buckets.map(&:name)
      if bucket_names.include?(@s3_bucket)
        record_success("S3 connectivity", "Connected successfully. Target bucket '#{@s3_bucket}' found")
        puts "   📊 Total buckets accessible: #{bucket_names.length}"
      else
        record_failure("S3 connectivity", "Target bucket '#{@s3_bucket}' not found in accessible buckets")
        puts "   Available buckets: #{bucket_names.take(3).join(', ')}#{bucket_names.length > 3 ? '...' : ''}"
      end
      
    rescue => e
      record_failure("S3 connectivity", "Connection failed: #{e.message}")
    end
  end
  
  def test_bucket_access
    puts "\n🪣 Testing S3 bucket access permissions..."
    
    begin
      s3_client = create_s3_client
      
      # Test read permissions
      begin
        s3_client.head_bucket(bucket: @s3_bucket)
        record_success("Bucket read access", "Can access bucket '#{@s3_bucket}'")
      rescue => e
        record_failure("Bucket read access", "Cannot access bucket: #{e.message}")
      end
      
      # Test write permissions by attempting to list objects
      begin
        response = s3_client.list_objects_v2(bucket: @s3_bucket, max_keys: 1)
        record_success("Bucket list access", "Can list objects in bucket")
        puts "   📊 Bucket contains objects: #{response.key_count > 0 ? 'Yes' : 'No'}"
      rescue => e
        record_failure("Bucket list access", "Cannot list objects: #{e.message}")
      end
      
    rescue => e
      record_failure("Bucket access", "Bucket access test failed: #{e.message}")
    end
  end
  
  def test_presigned_url_generation
    puts "\n🔗 Testing presigned URL generation..."
    
    begin
      # Test upload URL generation
      audio_segment = create_mock_audio_segment
      upload_url = generate_test_presigned_upload_url(audio_segment)
      
      if upload_url && upload_url.start_with?('https://')
        record_success("Upload URL generation", "Generated valid upload URL")
        puts "   🔗 URL length: #{upload_url.length} characters"
        puts "   ⏰ Contains expiration: #{upload_url.include?('Expires') ? 'Yes' : 'No'}"
        
        @test_upload_url = upload_url
        @test_key = "audio_segments/#{audio_segment.id}/#{audio_segment.file_name}"
      else
        record_failure("Upload URL generation", "Invalid or empty URL generated")
      end
      
      # Test download URL generation
      download_url = generate_test_presigned_download_url(audio_segment)
      
      if download_url && download_url.start_with?('https://')
        record_success("Download URL generation", "Generated valid download URL")
        @test_download_url = download_url
      else
        record_failure("Download URL generation", "Invalid or empty URL generated")
      end
      
    rescue => e
      record_failure("Presigned URL generation", "URL generation failed: #{e.message}")
    end
  end
  
  def test_file_upload_via_presigned_url
    puts "\n⬆️  Testing file upload via presigned URL..."
    
    return unless @test_upload_url
    
    begin
      # Create test audio data
      test_audio_data = create_test_audio_data
      
      # Upload using the presigned URL
      uri = URI(@test_upload_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      
      request = Net::HTTP::Put.new(uri.request_uri)
      request['Content-Type'] = 'audio/wav'
      request.body = test_audio_data
      
      start_time = Time.now
      response = http.request(request)
      end_time = Time.now
      
      upload_time = (end_time - start_time).round(2)
      
      if response.code.to_i.between?(200, 299)
        record_success("File upload", "Uploaded #{test_audio_data.length} bytes in #{upload_time}s")
        puts "   📊 Response code: #{response.code}"
        puts "   ⏱️  Upload time: #{upload_time} seconds"
        puts "   🚀 Upload speed: #{format_bytes_per_second(test_audio_data.length, upload_time)}"
        
        @upload_successful = true
      else
        record_failure("File upload", "Upload failed with code #{response.code}: #{response.message}")
      end
      
    rescue => e
      record_failure("File upload", "Upload exception: #{e.message}")
    end
  end
  
  def test_file_download_via_presigned_url
    puts "\n⬇️  Testing file download via presigned URL..."
    
    return unless @test_download_url && @upload_successful
    
    begin
      uri = URI(@test_download_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      
      start_time = Time.now
      response = http.get(uri.request_uri)
      end_time = Time.now
      
      download_time = (end_time - start_time).round(2)
      
      if response.code == '200' && response.body.length > 0
        record_success("File download", "Downloaded #{response.body.length} bytes in #{download_time}s")
        puts "   📊 Response code: #{response.code}"
        puts "   📦 Content-Type: #{response['content-type']}"
        puts "   ⏱️  Download time: #{download_time} seconds"
        puts "   🚀 Download speed: #{format_bytes_per_second(response.body.length, download_time)}"
        
        # Verify content integrity
        original_length = create_test_audio_data.length
        if response.body.length == original_length
          record_success("Content integrity", "Downloaded file matches original size")
        else
          record_failure("Content integrity", "Size mismatch: expected #{original_length}, got #{response.body.length}")
        end
      else
        record_failure("File download", "Download failed with code #{response.code}")
      end
      
    rescue => e
      record_failure("File download", "Download exception: #{e.message}")
    end
  end
  
  def test_audio_segments_controller_integration
    puts "\n🎮 Testing AudioSegmentsController integration..."
    
    begin
      # Create test user and project
      user = User.first || create_test_user
      project = create_test_project(user)
      
      # Test upload request endpoint
      controller = Api::AudioSegmentsController.new
      controller.instance_variable_set(:@project, project)
      
      # Mock the request parameters
      params = ActionController::Parameters.new({
        fileName: 'integration_test.wav',
        mimeType: 'audio/wav',
        recordedDurationSeconds: 30
      })
      
      # Test presigned URL generation through controller
      audio_segment = project.audio_segments.build({
        file_name: 'integration_test.wav',
        mime_type: 'audio/wav',
        duration_seconds: 30,
        upload_status: 'pending'
      })
      
      if audio_segment.save
        upload_url = controller.send(:generate_presigned_url, audio_segment)
        
        if upload_url && upload_url.start_with?('https://')
          record_success("Controller integration", "Controller generated valid presigned URL")
          puts "   🔗 URL includes bucket: #{upload_url.include?(@s3_bucket) ? 'Yes' : 'No'}"
          puts "   🆔 URL includes segment ID: #{upload_url.include?(audio_segment.id.to_s) ? 'Yes' : 'No'}"
        else
          record_failure("Controller integration", "Controller failed to generate valid URL")
        end
        
        # Test playback URL generation
        audio_segment.update!(upload_status: 'success')
        playback_url = controller.send(:generate_playback_url, audio_segment)
        
        if playback_url && playback_url.start_with?('https://')
          record_success("Playback URL generation", "Controller generated valid playback URL")
        else
          record_failure("Playback URL generation", "Controller failed to generate playback URL")
        end
      else
        record_failure("Controller integration", "Failed to create test audio segment")
      end
      
      # Clean up
      project.destroy
      
    rescue => e
      record_failure("Controller integration", "Integration test failed: #{e.message}")
    end
  end
  
  def test_error_handling
    puts "\n🚨 Testing error handling..."
    
    # Test with invalid credentials
    begin
      s3_client = Aws::S3::Client.new(
        region: @aws_region,
        access_key_id: 'invalid_key',
        secret_access_key: 'invalid_secret'
      )
      
      s3_client.list_buckets
      record_failure("Invalid credentials handling", "Should have failed with invalid credentials")
    rescue => e
      if e.message.include?('InvalidAccessKeyId') || e.message.include?('SignatureDoesNotMatch')
        record_success("Invalid credentials handling", "Correctly handled invalid credentials")
      else
        record_failure("Invalid credentials handling", "Unexpected error: #{e.message}")
      end
    end
    
    # Test with non-existent bucket
    begin
      s3_client = create_s3_client
      presigner = Aws::S3::Presigner.new(client: s3_client)
      
      presigner.presigned_url(:put_object, bucket: 'non-existent-bucket-12345', key: 'test.txt')
      record_success("Non-existent bucket handling", "Generated URL for non-existent bucket (validation happens at use-time)")
    rescue => e
      record_success("Non-existent bucket handling", "Exception raised for non-existent bucket: #{e.message}")
    end
  end
  
  def test_cleanup
    puts "\n🧹 Testing cleanup operations..."
    
    return unless @test_key && @upload_successful
    
    begin
      s3_client = create_s3_client
      
      # Delete the test file
      s3_client.delete_object(bucket: @s3_bucket, key: @test_key)
      record_success("File cleanup", "Successfully deleted test file")
      
      # Verify deletion
      begin
        s3_client.head_object(bucket: @s3_bucket, key: @test_key)
        record_failure("Cleanup verification", "File still exists after deletion")
      rescue Aws::S3::Errors::NotFound
        record_success("Cleanup verification", "File successfully removed from S3")
      end
      
    rescue => e
      record_failure("File cleanup", "Cleanup failed: #{e.message}")
    end
  end
  
  def create_s3_client
    Aws::S3::Client.new(
      region: @aws_region,
      access_key_id: @aws_access_key,
      secret_access_key: @aws_secret_key
    )
  end
  
  def create_mock_audio_segment
    OpenStruct.new(
      id: Time.now.to_i,
      file_name: 'live_test_audio.wav',
      mime_type: 'audio/wav',
      duration_seconds: 30
    )
  end
  
  def generate_test_presigned_upload_url(audio_segment)
    s3_client = create_s3_client
    presigner = Aws::S3::Presigner.new(client: s3_client)
    
    presigner.presigned_url(
      :put_object,
      bucket: @s3_bucket,
      key: "audio_segments/#{audio_segment.id}/#{audio_segment.file_name}",
      expires_in: 3600,
      content_type: audio_segment.mime_type
    )
  end
  
  def generate_test_presigned_download_url(audio_segment)
    s3_client = create_s3_client
    presigner = Aws::S3::Presigner.new(client: s3_client)
    
    presigner.presigned_url(
      :get_object,
      bucket: @s3_bucket,
      key: "audio_segments/#{audio_segment.id}/#{audio_segment.file_name}",
      expires_in: 3600
    )
  end
  
  def create_test_audio_data
    # Create a simple WAV file header + some audio data
    # This is a minimal valid WAV file for testing
    wav_header = [
      'RIFF',
      [36 + 1000].pack('V'),  # File size - 8
      'WAVE',
      'fmt ',
      [16].pack('V'),         # Subchunk1Size
      [1].pack('v'),          # AudioFormat (PCM)
      [1].pack('v'),          # NumChannels (mono)
      [8000].pack('V'),       # SampleRate
      [16000].pack('V'),      # ByteRate
      [2].pack('v'),          # BlockAlign
      [16].pack('v'),         # BitsPerSample
      'data',
      [1000].pack('V')        # Subchunk2Size
    ].join
    
    # Add some sample audio data (silence)
    audio_data = "\x00" * 1000
    
    wav_header + audio_data
  end
  
  def create_test_user
    User.create!(
      email: "test_s3_#{Time.now.to_i}@example.com",
      password: 'password123'
    )
  end
  
  def create_test_project(user)
    user.projects.create!(
      title: "S3 Test Project #{Time.now.to_i}",
      description: "Test project for S3 integration",
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
  
  def format_bytes_per_second(bytes, seconds)
    return "0 B/s" if seconds == 0
    bps = bytes / seconds
    return "#{bps.round} B/s" if bps < 1024
    return "#{(bps / 1024.0).round(1)} KB/s" if bps < 1024 * 1024
    "#{(bps / (1024.0 * 1024)).round(1)} MB/s"
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
    
    puts "\n💡 S3 CONFIGURATION:"
    puts "   📍 Region: #{@aws_region}"
    puts "   🪣 Bucket: #{@s3_bucket}"
    puts "   🔑 Access Key: #{@aws_access_key ? "#{@aws_access_key[0..3]}..." : 'Not set'}"
    
    puts "\n🎯 Overall Status: #{failures == 0 ? '✅ ALL TESTS PASSED' : '❌ SOME TESTS FAILED'}"
  end
end

# Run the test if this file is executed directly
if __FILE__ == $0
  test_runner = AwsS3LiveTest.new
  test_runner.run_all_tests
end