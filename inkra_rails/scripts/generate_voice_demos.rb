#!/usr/bin/env ruby

# Voice Demo Generator Script
#
# This script generates voice demo audio files for each available Polly voice,
# where each voice says the demo text:
# "This is your interview — a moment to own your journey.
# I'm {NAME}, and I'll ask what matters — so you can discover what's true for you."

require_relative '../config/environment'

class VoiceDemoGenerator
  DEMO_TEXT_TEMPLATE = "This is your interview — a moment to own your journey. I'm %{name}, and I'll ask what matters — so you can discover what's true for you."
  
  # Available Polly voices with their configurations
  VOICES = [
    { id: 'Joanna', name: 'Joanna', gender: 'Female', language: 'en-US', neural: true },
    { id: 'Matthew', name: 'Matthew', gender: 'Male', language: 'en-US', neural: true },
    { id: 'Amy', name: 'Amy', gender: 'Female', language: 'en-GB', neural: true },
    { id: 'Brian', name: 'Brian', gender: 'Male', language: 'en-GB', neural: true },
    { id: 'Emma', name: 'Emma', gender: 'Female', language: 'en-GB', neural: true },
    { id: 'Olivia', name: 'Olivia', gender: 'Female', language: 'en-AU', neural: true },
    { id: 'Arthur', name: 'Arthur', gender: 'Male', language: 'en-GB', neural: true },
    { id: 'Aria', name: 'Aria', gender: 'Female', language: 'en-NZ', neural: true },
    { id: 'Ruth', name: 'Ruth', gender: 'Female', language: 'en-US', neural: true },
    { id: 'Stephen', name: 'Stephen', gender: 'Male', language: 'en-US', neural: true },
    { id: 'Gregory', name: 'Gregory', gender: 'Male', language: 'en-US', neural: true },
    { id: 'Ivy', name: 'Ivy', gender: 'Female', language: 'en-US', neural: true },
    { id: 'Justin', name: 'Justin', gender: 'Male', language: 'en-US', neural: true },
    { id: 'Kendra', name: 'Kendra', gender: 'Female', language: 'en-US', neural: true },
    { id: 'Kimberly', name: 'Kimberly', gender: 'Female', language: 'en-US', neural: true },
    { id: 'Salli', name: 'Salli', gender: 'Female', language: 'en-US', neural: true }
  ].freeze
  
  def initialize
    @polly_client = Aws::Polly::Client.new(
      region: ENV['AWS_REGION'] || 'us-east-1'
    )
    @s3_client = Aws::S3::Client.new(
      region: ENV['AWS_REGION'] || 'us-east-1'
    )
    @bucket_name = ENV['AWS_S3_BUCKET']
    
    unless @bucket_name
      raise "AWS_S3_BUCKET environment variable is required"
    end
  end
  
  def generate_all_demos
    puts "🎙️ Starting voice demo generation for #{VOICES.count} voices..."
    puts "📦 Using S3 bucket: #{@bucket_name}"
    puts
    
    successful_generations = 0
    failed_generations = 0
    
    VOICES.each_with_index do |voice_config, index|
      puts "[#{index + 1}/#{VOICES.count}] Generating demo for #{voice_config[:name]} (#{voice_config[:gender]}, #{voice_config[:language]})"
      
      begin
        generate_voice_demo(voice_config)
        successful_generations += 1
        puts "✅ Successfully generated demo for #{voice_config[:name]}"
      rescue => error
        failed_generations += 1
        puts "❌ Failed to generate demo for #{voice_config[:name]}: #{error.message}"
        puts "   Error details: #{error.backtrace.first}" if ENV['DEBUG']
      end
      
      puts
    end
    
    puts "🎯 Generation complete!"
    puts "   ✅ Successful: #{successful_generations}"
    puts "   ❌ Failed: #{failed_generations}"
    puts "   📊 Success rate: #{(successful_generations.to_f / VOICES.count * 100).round(1)}%"
  end
  
  private
  
  def generate_voice_demo(voice_config)
    # Generate the demo text with the voice name
    demo_text = DEMO_TEXT_TEMPLATE % { name: voice_config[:name] }
    
    # Generate speech using Polly
    polly_response = @polly_client.synthesize_speech({
      text: demo_text,
      output_format: 'mp3',
      voice_id: voice_config[:id],
      engine: voice_config[:neural] ? 'neural' : 'standard',
      language_code: voice_config[:language],
      text_type: 'text'
    })
    
    # Generate S3 key for the demo file
    s3_key = "voice_demos/#{voice_config[:id].downcase}_demo.mp3"
    
    # Upload to S3
    @s3_client.put_object({
      bucket: @bucket_name,
      key: s3_key,
      body: polly_response.audio_stream,
      content_type: 'audio/mpeg',
      metadata: {
        'voice-id' => voice_config[:id],
        'voice-name' => voice_config[:name],
        'voice-gender' => voice_config[:gender],
        'voice-language' => voice_config[:language],
        'generated-at' => Time.current.iso8601,
        'demo-type' => 'interview-introduction'
      }
    })
    
    # Generate public URL
    s3_url = "https://#{@bucket_name}.s3.#{ENV['AWS_REGION'] || 'us-east-1'}.amazonaws.com/#{s3_key}"
    
    puts "   📁 Uploaded to: #{s3_url}"
    puts "   📝 Demo text: #{demo_text.truncate(80)}"
    
    return {
      voice: voice_config,
      s3_key: s3_key,
      s3_url: s3_url,
      demo_text: demo_text
    }
  end
end

# Script execution
if __FILE__ == $0
  begin
    puts "🚀 Voice Demo Generator"
    puts "=" * 50
    puts
    
    # Check for required environment variables
    required_env_vars = ['AWS_ACCESS_KEY_ID', 'AWS_SECRET_ACCESS_KEY', 'AWS_REGION', 'AWS_S3_BUCKET']
    missing_vars = required_env_vars.select { |var| ENV[var].nil? }
    
    if missing_vars.any?
      puts "❌ Missing required environment variables:"
      missing_vars.each { |var| puts "   - #{var}" }
      puts
      puts "Please set these environment variables and try again."
      exit 1
    end
    
    generator = VoiceDemoGenerator.new
    generator.generate_all_demos
    
    puts
    puts "🎉 All done! Voice demos are ready for use."
    
  rescue Interrupt
    puts "\n⚠️ Generation interrupted by user"
    exit 1
  rescue => error
    puts "\n💥 Fatal error: #{error.message}"
    puts "Stack trace:" if ENV['DEBUG']
    puts error.backtrace.join("\n") if ENV['DEBUG']
    exit 1
  end
end