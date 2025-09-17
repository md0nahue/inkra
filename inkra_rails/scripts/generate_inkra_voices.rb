#!/usr/bin/env ruby

# Inkra Voice Generator Script
#
# This script generates 10 diverse voices with unique welcome phrases introducing users to Inkra.
# Each voice has a personalized intro phrase that welcomes users and introduces the voice.

require_relative '../config/environment'

class InkraVoiceGenerator
  # 10 carefully selected diverse voices (no child voices)
  INKRA_VOICES = [
    {
      id: 'Matthew',
      name: 'Matthew',
      gender: 'Male',
      language: 'en-US',
      neural: true,
      phrase: "Welcome to Inkra! I'm Matthew, your thoughtful interviewer. Together, we'll explore the stories that define who you are and uncover the insights that matter most to your journey."
    },
    {
      id: 'Joanna',
      name: 'Joanna',
      gender: 'Female',
      language: 'en-US',
      neural: true,
      phrase: "Hello, and welcome to Inkra! I'm Joanna. Think of me as your personal storytelling companion, here to guide you through meaningful conversations that reveal the depth of your experiences."
    },
    {
      id: 'Arthur',
      name: 'Arthur',
      gender: 'Male',
      language: 'en-GB',
      neural: true,
      phrase: "Greetings! I'm Arthur, and I'm delighted to welcome you to Inkra. Let's embark on a journey of self-discovery together, where every question opens a door to understanding your unique story."
    },
    {
      id: 'Emma',
      name: 'Emma',
      gender: 'Female',
      language: 'en-GB',
      neural: true,
      phrase: "Welcome to Inkra! I'm Emma, your curious conversation partner. I'm here to help you dive deep into the moments and memories that have shaped your remarkable journey through life."
    },
    {
      id: 'Olivia',
      name: 'Olivia',
      gender: 'Female',
      language: 'en-AU',
      neural: true,
      phrase: "G'day! I'm Olivia, and I'm thrilled to welcome you to Inkra. Let's have a yarn about the experiences that make you uniquely you - every story deserves to be heard and celebrated."
    },
    {
      id: 'Brian',
      name: 'Brian',
      gender: 'Male',
      language: 'en-GB',
      neural: true,
      phrase: "Welcome to the Inkra experience! I'm Brian, and I'll be your guide as we explore the fascinating tapestry of your life's journey, one meaningful conversation at a time."
    },
    {
      id: 'Ruth',
      name: 'Ruth',
      gender: 'Female',
      language: 'en-US',
      neural: true,
      phrase: "Hello there! I'm Ruth, and I'm so glad you've joined us on Inkra. Together, we'll unlock the power of your personal narrative and discover the wisdom hidden within your experiences."
    },
    {
      id: 'Stephen',
      name: 'Stephen',
      gender: 'Male',
      language: 'en-US',
      neural: true,
      phrase: "Welcome to Inkra! I'm Stephen, your dedicated interviewer. I believe every person has profound stories worth telling, and I'm here to help you share yours with clarity and purpose."
    },
    {
      id: 'Aria',
      name: 'Aria',
      gender: 'Female',
      language: 'en-NZ',
      neural: true,
      phrase: "Kia ora! Welcome to Inkra! I'm Aria, and I'm here to help you explore the rich landscape of your personal journey. Let's discover together what makes your story truly extraordinary."
    },
    {
      id: 'Kendra',
      name: 'Kendra',
      gender: 'Female',
      language: 'en-US',
      neural: true,
      phrase: "Welcome to Inkra! I'm Kendra, your warm and encouraging guide. I'm here to help you explore your unique journey and discover the remarkable stories that have shaped who you are today."
    }
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
  
  def generate_all_inkra_voices
    puts "🌟 Starting Inkra voice welcome generation for #{INKRA_VOICES.count} diverse voices..."
    puts "📦 Using S3 bucket: #{@bucket_name}"
    puts "🚫 Excluding child voices per requirements"
    puts
    
    successful_generations = 0
    failed_generations = 0
    generated_voices = []
    
    INKRA_VOICES.each_with_index do |voice_config, index|
      puts "[#{index + 1}/#{INKRA_VOICES.count}] Generating Inkra welcome for #{voice_config[:name]} (#{voice_config[:gender]}, #{voice_config[:language]})"
      
      begin
        result = generate_inkra_voice(voice_config)
        successful_generations += 1
        generated_voices << result
        puts "✅ Successfully generated Inkra welcome for #{voice_config[:name]}"
      rescue => error
        failed_generations += 1
        puts "❌ Failed to generate Inkra welcome for #{voice_config[:name]}: #{error.message}"
        puts "   Error details: #{error.backtrace.first}" if ENV['DEBUG']
      end
      
      puts
    end
    
    puts "🎯 Inkra voice generation complete!"
    puts "   ✅ Successful: #{successful_generations}"
    puts "   ❌ Failed: #{failed_generations}"
    puts "   📊 Success rate: #{(successful_generations.to_f / INKRA_VOICES.count * 100).round(1)}%"
    puts
    puts "🎙️ Generated voices summary:"
    generated_voices.each do |voice|
      puts "   #{voice[:voice][:name]} (#{voice[:voice][:gender]}): #{voice[:s3_url]}"
    end
    
    return generated_voices
  end
  
  private
  
  def generate_inkra_voice(voice_config)
    # Use the custom Inkra phrase for this voice
    inkra_phrase = voice_config[:phrase]
    
    # Generate speech using Polly
    polly_response = @polly_client.synthesize_speech({
      text: inkra_phrase,
      output_format: 'mp3',
      voice_id: voice_config[:id],
      engine: voice_config[:neural] ? 'neural' : 'standard',
      language_code: voice_config[:language],
      text_type: 'text'
    })
    
    # Generate S3 key for the Inkra welcome file
    s3_key = "inkra_voice_welcomes/#{voice_config[:id].downcase}_inkra_welcome.mp3"
    
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
        'demo-type' => 'inkra-welcome',
        'app-name' => 'inkra'
      }
    })
    
    # Generate public URL
    s3_url = "https://#{@bucket_name}.s3.#{ENV['AWS_REGION'] || 'us-east-1'}.amazonaws.com/#{s3_key}"
    
    puts "   📁 Uploaded to: #{s3_url}"
    puts "   📝 Inkra phrase: #{inkra_phrase.truncate(100)}"
    
    return {
      voice: voice_config,
      s3_key: s3_key,
      s3_url: s3_url,
      inkra_phrase: inkra_phrase
    }
  end
end

# Script execution
if __FILE__ == $0
  begin
    puts "🌟 Inkra Voice Welcome Generator"
    puts "=" * 60
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
    
    generator = InkraVoiceGenerator.new
    generator.generate_all_inkra_voices
    
    puts
    puts "🎉 All Inkra voice welcomes are ready! Users can now hear diverse, welcoming introductions."
    
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