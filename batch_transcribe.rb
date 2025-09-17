#!/usr/bin/env ruby

# Batch transcription script for recordings directory
# This script uploads audio files to S3 and transcribes them using Groq

require_relative 'inkra_rails/config/environment'
require 'fileutils'
require 'ostruct'

class BatchTranscriber
  def initialize
    @recordings_dir = File.join(Dir.pwd, 'recordings')
    @output_dir = File.join(Dir.pwd, 'transcriptions')
    @api_key = ENV['GROQ_API_KEY'] || Rails.application.credentials.dig(:groq, :api_key)

    setup_output_directory
    validate_setup
  end

  def run
    puts "🎤 Starting batch transcription of recordings..."
    puts "📁 Input directory: #{@recordings_dir}"
    puts "📝 Output directory: #{@output_dir}"
    puts "=" * 60

    audio_files = get_audio_files

    if audio_files.empty?
      puts "❌ No audio files found in #{@recordings_dir}"
      return
    end

    puts "🔍 Found #{audio_files.length} audio files:"
    audio_files.each { |file| puts "   • #{File.basename(file)}" }
    puts

    # Create dummy user for S3 service
    user = create_or_get_dummy_user
    s3_service = S3Service.new(user)

    success_count = 0
    failed_files = []

    audio_files.each_with_index do |file_path, index|
      filename = File.basename(file_path)
      puts "🎵 Processing #{index + 1}/#{audio_files.length}: #{filename}"

      begin
        # Read audio file
        audio_data = File.read(file_path, mode: 'rb')

        # Upload to S3 first
        puts "   📤 Uploading to S3..."
        upload_result = upload_to_s3(s3_service, audio_data, filename)

        if upload_result[:success]
          puts "   ✅ Upload successful"

          # Transcribe with Groq
          puts "   🤖 Transcribing with Groq..."
          transcription_result = transcribe_with_groq(audio_data, filename)

          if transcription_result[:success]
            # Save transcription to file
            output_filename = File.basename(filename, File.extname(filename)) + '.txt'
            output_path = File.join(@output_dir, output_filename)

            File.write(output_path, transcription_result[:text])
            puts "   ✅ Transcription saved to #{output_filename}"
            puts "   📊 Text length: #{transcription_result[:text].length} characters"
            success_count += 1
          else
            puts "   ❌ Transcription failed: #{transcription_result[:error]}"
            failed_files << filename
          end
        else
          puts "   ❌ Upload failed: #{upload_result[:error]}"
          failed_files << filename
        end

      rescue => e
        puts "   ❌ Error processing #{filename}: #{e.message}"
        failed_files << filename
      end

      puts
    end

    print_summary(success_count, failed_files, audio_files.length)
  end

  private

  def setup_output_directory
    FileUtils.mkdir_p(@output_dir) unless Dir.exist?(@output_dir)
  end

  def validate_setup
    unless Dir.exist?(@recordings_dir)
      puts "❌ Recordings directory not found: #{@recordings_dir}"
      exit(1)
    end

    unless @api_key
      puts "❌ Groq API key not found"
      puts "   Set GROQ_API_KEY environment variable or configure in Rails credentials"
      exit(1)
    end

    puts "✅ Setup validated"
  end

  def get_audio_files
    Dir.glob(File.join(@recordings_dir, '*.{m4a,mp3,wav,aac,ogg}')).sort
  end

  def create_or_get_dummy_user
    # Try to find existing user or create a dummy one for S3 operations
    user = User.first
    unless user
      user = User.create!(
        email: "batch_transcriber_#{Time.now.to_i}@example.com",
        password: SecureRandom.hex(16)
      )
    end
    user
  end

  def upload_to_s3(s3_service, audio_data, filename)
    begin
      # Generate a unique key for S3
      timestamp = Time.now.to_i
      s3_key = "transcription_batch/#{timestamp}_#{filename}"

      # Upload directly to S3
      bucket_name = Rails.application.credentials.dig(:aws, :s3_bucket) || ENV['AWS_S3_BUCKET'] || 'vibewrite-audio-dev'

      s3_client = Aws::S3::Client.new(
        region: s3_service.send(:aws_region),
        access_key_id: s3_service.send(:aws_access_key_id),
        secret_access_key: s3_service.send(:aws_secret_access_key)
      )

      s3_client.put_object(
        bucket: bucket_name,
        key: s3_key,
        body: audio_data,
        content_type: get_content_type(filename)
      )

      { success: true, s3_key: s3_key }
    rescue => e
      { success: false, error: e.message }
    end
  end

  def transcribe_with_groq(audio_data, filename)
    begin
      # Create mock audio segment for compatibility with existing service
      mock_segment = OpenStruct.new(
        id: "batch_#{Time.now.to_i}",
        file_name: filename,
        mime_type: get_content_type(filename)
      )

      # Use the existing TranscriptionService method
      result = TranscriptionService.send(:transcribe_with_groq, audio_data, mock_segment, @api_key)

      if result[:success]
        { success: true, text: result[:text] }
      else
        { success: false, error: result[:error] }
      end

    rescue => e
      { success: false, error: e.message }
    end
  end

  def get_content_type(filename)
    case File.extname(filename).downcase
    when '.m4a'
      'audio/mp4'
    when '.mp3'
      'audio/mpeg'
    when '.wav'
      'audio/wav'
    when '.aac'
      'audio/aac'
    when '.ogg'
      'audio/ogg'
    else
      'audio/mpeg'
    end
  end

  def print_summary(success_count, failed_files, total_count)
    puts "=" * 60
    puts "📊 TRANSCRIPTION SUMMARY"
    puts "=" * 60
    puts "✅ Successful: #{success_count}/#{total_count}"
    puts "❌ Failed: #{failed_files.length}/#{total_count}" if failed_files.any?
    puts "📈 Success Rate: #{((success_count.to_f / total_count) * 100).round(1)}%"

    if failed_files.any?
      puts "\n💥 Failed files:"
      failed_files.each { |file| puts "   • #{file}" }
    end

    if success_count > 0
      puts "\n📝 Transcription files saved to: #{@output_dir}"
    end

    puts "\n🎯 Overall Status: #{failed_files.empty? ? '✅ ALL FILES PROCESSED' : '⚠️  SOME FILES FAILED'}"
  end
end

# Run the batch transcriber
if __FILE__ == $0
  transcriber = BatchTranscriber.new
  transcriber.run
end