class VoiceDemoGenerator
  DEMO_TEXT = "Hi there! This is a sample of my voice. I can help bring your story to life with natural, expressive narration."
  
  CURATED_VOICES = [
    { id: 'Matthew', engine: 'neural' },
    { id: 'Joanna', engine: 'neural' },
    { id: 'Amy', engine: 'neural' },
    { id: 'Brian', engine: 'neural' },
    { id: 'Emma', engine: 'neural' },
    { id: 'Olivia', engine: 'neural' },
    { id: 'Arthur', engine: 'neural' },
    { id: 'Daniel', engine: 'neural' },
    { id: 'Aria', engine: 'neural' },
    { id: 'Gregory', engine: 'neural' }
  ]

  def self.generate_all_demos
    CURATED_VOICES.map do |voice_config|
      generate_demo(voice_config[:id], voice_config[:engine])
    end
  end

  def self.generate_demo(voice_id, engine = 'neural')
    polly_client = Aws::Polly::Client.new(
      region: ENV['AWS_REGION'] || 'us-east-1',
      access_key_id: ENV['AWS_ACCESS_KEY_ID'],
      secret_access_key: ENV['AWS_SECRET_ACCESS_KEY']
    )

    s3_client = Aws::S3::Client.new(
      region: ENV['AWS_REGION'] || 'us-east-1',
      access_key_id: ENV['AWS_ACCESS_KEY_ID'],
      secret_access_key: ENV['AWS_SECRET_ACCESS_KEY']
    )

    # Generate audio with Polly
    response = polly_client.synthesize_speech({
      text: DEMO_TEXT,
      voice_id: voice_id,
      output_format: 'mp3',
      engine: engine
    })

    # Upload to S3
    s3_key = "voice_demos/#{voice_id.downcase}_demo.mp3"
    bucket = ENV['AWS_S3_BUCKET']
    
    s3_client.put_object({
      bucket: bucket,
      key: s3_key,
      body: response.audio_stream,
      content_type: 'audio/mpeg'
    })

    # Return the public URL
    "https://#{bucket}.s3.amazonaws.com/#{s3_key}"
  rescue => e
    Rails.logger.error "Failed to generate demo for voice #{voice_id}: #{e.message}"
    nil
  end

  def self.get_all_voice_urls
    CURATED_VOICES.map do |voice|
      {
        voice_id: voice[:id],
        engine: voice[:engine],
        demo_url: "https://#{ENV['AWS_S3_BUCKET']}.s3.amazonaws.com/voice_demos/#{voice[:id].downcase}_demo.mp3"
      }
    end
  end
end