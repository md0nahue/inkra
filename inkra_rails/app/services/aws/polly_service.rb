module Aws
  class PollyService
    # Curated list of 10 high-quality voices for the best user experience
    SELECTED_VOICES = [
      # US English (5 voices)
      { id: 'Matthew', name: 'Matthew', gender: 'Male', neural: true, standard: true, language_code: 'en-US' },
      { id: 'Joanna', name: 'Joanna', gender: 'Female', neural: true, standard: true, language_code: 'en-US' },
      { id: 'Ruth', name: 'Ruth', gender: 'Female', neural: true, standard: true, language_code: 'en-US' },
      { id: 'Stephen', name: 'Stephen', gender: 'Male', neural: true, standard: true, language_code: 'en-US' },
      { id: 'Kendra', name: 'Kendra', gender: 'Female', neural: true, standard: true, language_code: 'en-US' },
      
      # British English (3 voices)
      { id: 'Arthur', name: 'Arthur', gender: 'Male', neural: true, standard: true, language_code: 'en-GB' },
      { id: 'Emma', name: 'Emma', gender: 'Female', neural: true, standard: false, language_code: 'en-GB' },
      { id: 'Brian', name: 'Brian', gender: 'Male', neural: true, standard: true, language_code: 'en-GB' },
      
      # Other English variants (2 voices)
      { id: 'Olivia', name: 'Olivia', gender: 'Female', neural: true, standard: false, language_code: 'en-AU' },
      { id: 'Aria', name: 'Aria', gender: 'Female', neural: true, standard: false, language_code: 'en-NZ' }
    ].freeze
    
    # Full list of all available voices for speech generation (kept for backward compatibility)
    ENGLISH_VOICES = [
      # US English (en-US)
      { id: 'Danielle', name: 'Danielle (US)', gender: 'Female', neural: true, standard: false, language_code: 'en-US' },
      { id: 'Gregory', name: 'Gregory (US)', gender: 'Male', neural: false, standard: true, language_code: 'en-US' },
      { id: 'Ivy', name: 'Ivy (US Child)', gender: 'Female', neural: true, standard: false, language_code: 'en-US' },
      { id: 'Joanna', name: 'Joanna (US)', gender: 'Female', neural: true, standard: true, language_code: 'en-US' },
      { id: 'Kendra', name: 'Kendra (US)', gender: 'Female', neural: true, standard: true, language_code: 'en-US' },
      { id: 'Kimberly', name: 'Kimberly (US)', gender: 'Female', neural: true, standard: true, language_code: 'en-US' },
      { id: 'Salli', name: 'Salli (US)', gender: 'Female', neural: true, standard: true, language_code: 'en-US' },
      { id: 'Joey', name: 'Joey (US)', gender: 'Male', neural: true, standard: true, language_code: 'en-US' },
      { id: 'Justin', name: 'Justin (US Child)', gender: 'Male', neural: true, standard: true, language_code: 'en-US' },
      { id: 'Kevin', name: 'Kevin (US Child)', gender: 'Male', neural: true, standard: true, language_code: 'en-US' },
      { id: 'Matthew', name: 'Matthew (US)', gender: 'Male', neural: true, standard: true, language_code: 'en-US' },
      { id: 'Ruth', name: 'Ruth (US)', gender: 'Female', neural: true, standard: true, language_code: 'en-US' },
      { id: 'Stephen', name: 'Stephen (US)', gender: 'Male', neural: true, standard: true, language_code: 'en-US' },
      
      # British English (en-GB)
      { id: 'Amy', name: 'Amy (British)', gender: 'Female', neural: true, standard: true, language_code: 'en-GB' },
      { id: 'Emma', name: 'Emma (British)', gender: 'Female', neural: true, standard: false, language_code: 'en-GB' },
      { id: 'Brian', name: 'Brian (British)', gender: 'Male', neural: true, standard: true, language_code: 'en-GB' },
      { id: 'Arthur', name: 'Arthur (British)', gender: 'Male', neural: true, standard: true, language_code: 'en-GB' },
      
      # Welsh English (en-GB-WLS)
      { id: 'Geraint', name: 'Geraint (Welsh)', gender: 'Male', neural: false, standard: true, language_code: 'en-GB-WLS' },
      
      # Australian English (en-AU)
      { id: 'Nicole', name: 'Nicole (Australian)', gender: 'Female', neural: false, standard: true, language_code: 'en-AU' },
      { id: 'Olivia', name: 'Olivia (Australian)', gender: 'Female', neural: true, standard: false, language_code: 'en-AU' },
      { id: 'Russell', name: 'Russell (Australian)', gender: 'Male', neural: false, standard: true, language_code: 'en-AU' },
      
      # Indian English (en-IN)
      { id: 'Aditi', name: 'Aditi (Indian)', gender: 'Female', neural: false, standard: true, language_code: 'en-IN' },
      { id: 'Raveena', name: 'Raveena (Indian)', gender: 'Female', neural: true, standard: false, language_code: 'en-IN' },
      { id: 'Kajal', name: 'Kajal (Indian)', gender: 'Female', neural: true, standard: false, language_code: 'en-IN' },
      
      # Irish English (en-IE)
      { id: 'Niamh', name: 'Niamh (Irish)', gender: 'Female', neural: true, standard: false, language_code: 'en-IE' },
      
      # New Zealand English (en-NZ)
      { id: 'Aria', name: 'Aria (New Zealand)', gender: 'Female', neural: true, standard: false, language_code: 'en-NZ' },
      
      # Singaporean English (en-SG)
      { id: 'Jasmine', name: 'Jasmine (Singaporean)', gender: 'Female', neural: true, standard: false, language_code: 'en-SG' },
      
      # South African English (en-ZA)
      { id: 'Ayanda', name: 'Ayanda (South African)', gender: 'Female', neural: true, standard: false, language_code: 'en-ZA' }
    ].freeze
    
    
    DEFAULT_LANGUAGE = 'en-US'
    DEFAULT_VOICE = 'Joanna'
    
    def initialize(user = nil)
      @client = Aws::Polly::Client.new(
        region: ENV.fetch('AWS_REGION', 'us-east-1'),
        access_key_id: ENV['AWS_ACCESS_KEY_ID'],
        secret_access_key: ENV['AWS_SECRET_ACCESS_KEY']
      )
      @s3_service = S3Service.new(user)
    end
    
    def generate_speech(text:, voice_id: DEFAULT_VOICE, speech_rate: 100, language_code: nil, engine: nil)
      validate_voice_id!(voice_id)
      
      tracker = PerformanceTracker.instance
      
      # Use development audio generation in development environment
      if Rails.env.development?
        return generate_development_speech(text: text, voice_id: voice_id, speech_rate: speech_rate)
      end
      
      # Get voice config to determine language if not provided
      voice_config = tracker.track_event('voice_config_lookup', { voice_id: voice_id }) do
        get_voice_config(voice_id)
      end
      language_code ||= voice_config[:language_code] if voice_config
      
      # Convert speech rate percentage to SSML prosody rate
      prosody_rate = "#{speech_rate}%"
      
      # Wrap text in SSML for better control
      ssml_text = build_ssml(text, prosody_rate)
      
      # Request speech synthesis
      response = tracker.track_event('aws_polly_synthesis', { 
        voice_id: voice_id,
        text_length: text.length,
        engine: engine || (voice_neural?(voice_id) ? 'neural' : 'standard')
      }) do
        @client.synthesize_speech({
          output_format: 'mp3',
          text: ssml_text,
          text_type: 'ssml',
          voice_id: voice_id,
          language_code: language_code || DEFAULT_LANGUAGE,
          engine: engine || (voice_neural?(voice_id) ? 'neural' : 'standard')
        })
      end
      
      # Generate unique S3 key
      s3_key = generate_s3_key(voice_id)
      
      # Upload to S3
      tracker.track_event('s3_upload', { key: s3_key }) do
        @s3_service.upload_audio_data(s3_key, response.audio_stream)
      end
      
      {
        s3_key: s3_key,
        content_type: response.content_type,
        request_characters: response.request_characters
      }
    rescue Aws::Polly::Errors::ServiceError => e
      Rails.logger.error "Polly service error: #{e.message}"
      raise
    end
    
    
    def list_english_voices
      SELECTED_VOICES
    end
    
    def list_all_voices
      ENGLISH_VOICES
    end
    
    def voice_available?(voice_id)
      list_all_voices.any? { |voice| voice[:id] == voice_id }
    end
    
    def get_voice_config(voice_id)
      list_all_voices.find { |v| v[:id] == voice_id }
    end
    
    private
    
    # Development audio generation using macOS 'say' command
    def generate_development_speech(text:, voice_id: DEFAULT_VOICE, speech_rate: 100)
      Rails.logger.info "🎵 Development mode: Using macOS 'say' command instead of AWS Polly for cost savings"
      
      tracker = PerformanceTracker.instance
      
      # Map Polly voices to macOS system voices
      Rails.logger.info "🎵 Input voice_id: '#{voice_id}' (class: #{voice_id.class})"
      macos_voice = tracker.track_event('macos_voice_mapping', { voice_id: voice_id }) do
        mapped = map_polly_to_macos_voice(voice_id)
        Rails.logger.info "🎵 Voice mapping result: '#{voice_id}' -> '#{mapped}'"
        mapped
      end
      
      # Validate that we have a valid macOS voice
      if macos_voice.nil? || macos_voice.strip.empty?
        Rails.logger.error "🎵 ERROR: macOS voice is nil or empty after mapping. Using fallback 'Alex'"
        macos_voice = 'Alex'
      end
      Rails.logger.info "🎵 Final macOS voice to use: '#{macos_voice}'"
      
      # Convert speech rate (100% = normal speed for say command)
      say_rate = (speech_rate * 2).clamp(50, 400) # say command uses words per minute, roughly 200 is normal
      
      # Generate temporary file
      temp_file = Rails.root.join('tmp', "say_#{SecureRandom.hex(8)}.aiff")
      mp3_file = Rails.root.join('tmp', "say_#{SecureRandom.hex(8)}.mp3")
      
      begin
        # Use macOS 'say' command to generate speech
        say_command = [
          'say',
          '-v', macos_voice,
          '-r', say_rate.to_s,
          '-o', temp_file.to_s,
          text
        ]
        
        Rails.logger.info "🎵 Executing: #{say_command.join(' ')}"
        
        # Track say command execution time
        result = tracker.track_event('macos_say_command', { 
          voice: macos_voice, 
          rate: say_rate, 
          text_length: text.length 
        }) do
          # Use backticks to capture stderr output
          output = `#{say_command.shelljoin} 2>&1`
          exit_status = $?
          success = exit_status && exit_status.exitstatus == 0
          Rails.logger.info "🎵 Say command output: #{output}" unless output.empty?
          Rails.logger.info "🎵 Say command exit status: #{exit_status&.exitstatus || 'nil'}"
          success
        end
        
        unless result
          exit_status = $?
          status_msg = exit_status ? exit_status.exitstatus : 'command not executed'
          raise "macOS 'say' command failed with exit status #{status_msg}"
        end
        
        # Check if the output file was actually created
        unless File.exist?(temp_file)
          Rails.logger.error "🎵 ERROR: Say command succeeded but output file not created"
          Rails.logger.error "🎵 Expected file: #{temp_file}"
          Rails.logger.error "🎵 Current directory: #{Dir.pwd}"
          Rails.logger.error "🎵 Temp directory contents: #{Dir.entries(Rails.root.join('tmp')).join(', ')}"
          raise "Say command succeeded but output file not created: #{temp_file}"
        end
        Rails.logger.info "🎵 Output file created successfully: #{temp_file} (#{File.size(temp_file)} bytes)"
        
        # Convert AIFF to MP3 using ffmpeg (if available) or just use AIFF
        audio_file, content_type = tracker.track_event('audio_format_conversion') do
          if system('which ffmpeg > /dev/null 2>&1')
            conversion_result = system('ffmpeg', '-i', temp_file.to_s, '-y', mp3_file.to_s, '-loglevel', 'error')
            audio_file = conversion_result ? mp3_file : temp_file
            content_type = conversion_result ? 'audio/mpeg' : 'audio/aiff'
            [audio_file, content_type]
          else
            Rails.logger.warn "🎵 ffmpeg not found, using AIFF format (consider installing ffmpeg for MP3 conversion)"
            [temp_file, 'audio/aiff']
          end
        end
        
        # Read the generated audio file
        audio_data = tracker.track_event('audio_file_read', { file_size: File.size(audio_file) }) do
          File.read(audio_file)
        end
        
        # Generate unique S3 key
        s3_key = generate_s3_key(voice_id)
        
        # Upload to S3 using StringIO
        tracker.track_event('s3_upload', { key: s3_key, size: audio_data.bytesize }) do
          audio_stream = StringIO.new(audio_data)
          @s3_service.upload_audio_data(s3_key, audio_stream)
        end
        
        Rails.logger.info "🎵 Development audio generated and uploaded to S3: #{s3_key}"
        
        {
          s3_key: s3_key,
          content_type: content_type,
          request_characters: text.length
        }
        
      ensure
        # Clean up temporary files
        tracker.track_event('temp_file_cleanup') do
          [temp_file, mp3_file].each do |file|
            File.delete(file) if File.exist?(file)
          end
        end
      end
    rescue => e
      Rails.logger.error "🎵 Development speech generation failed: #{e.class.name}: #{e.message}"
      Rails.logger.error "🎵 Backtrace: #{e.backtrace.first(5).join(', ')}"
      Rails.logger.error "🎵 Context: voice_id='#{voice_id}', speech_rate=#{speech_rate}, text_length=#{text&.length || 'nil'}"
      raise "Development speech generation failed: #{e.message}"
    end
    
    # Map Polly voice IDs to macOS system voices
    def map_polly_to_macos_voice(polly_voice_id)
      voice_mapping = {
        # US English voices
        'Matthew' => 'Alex',      # Male US voice
        'Joanna' => 'Samantha',   # Female US voice  
        'Ruth' => 'Victoria',     # Female US voice
        'Stephen' => 'Daniel',    # Male US voice
        'Kendra' => 'Kathy',      # Female US voice
        'Salli' => 'Samantha',    # Female US voice
        'Joey' => 'Alex',         # Male US voice
        'Justin' => 'Alex',       # Male US voice (child-like)
        'Kevin' => 'Alex',        # Male US voice (child-like)
        'Kimberly' => 'Kathy',    # Female US voice
        'Ivy' => 'Princess',      # Female US voice (child-like)
        'Danielle' => 'Samantha', # Female US voice
        'Gregory' => 'Daniel',    # Male US voice
        
        # British English voices
        'Arthur' => 'Daniel',     # Male British (closest approximation)
        'Emma' => 'Kate',         # Female British
        'Brian' => 'Oliver',      # Male British
        'Amy' => 'Kate',          # Female British
        
        # Other English variants (best approximations)
        'Olivia' => 'Karen',      # Australian Female
        'Nicole' => 'Karen',      # Australian Female
        'Russell' => 'Alex',      # Australian Male (approximation)
        'Aria' => 'Samantha',     # New Zealand Female (approximation)
        'Niamh' => 'Moira',       # Irish Female
        'Geraint' => 'Daniel',    # Welsh Male (approximation)
        'Aditi' => 'Veena',       # Indian Female
        'Raveena' => 'Veena',     # Indian Female
        'Kajal' => 'Veena',       # Indian Female
        'Jasmine' => 'Samantha',  # Singaporean Female (approximation)
        'Ayanda' => 'Samantha'    # South African Female (approximation)
      }
      
      mapped_voice = voice_mapping[polly_voice_id]
      
      if mapped_voice.nil?
        Rails.logger.warn "🎵 No macOS voice mapping found for '#{polly_voice_id}', using default 'Samantha'"
        mapped_voice = 'Samantha'
      end
      
      Rails.logger.info "🎵 Mapped Polly voice '#{polly_voice_id}' to macOS voice '#{mapped_voice}'"
      mapped_voice
    end
    
    def validate_voice_id!(voice_id)
      unless voice_available?(voice_id)
        raise ArgumentError, "Invalid voice_id: #{voice_id}. Available voices: #{list_all_voices.map { |v| v[:id] }.join(', ')}"
      end
    end
    
    def voice_neural?(voice_id)
      voice = get_voice_config(voice_id)
      voice && voice[:neural]
    end
    
    def build_ssml(text, prosody_rate)
      <<~SSML
        <speak>
          <prosody rate="#{prosody_rate}">
            #{CGI.escapeHTML(text)}
          </prosody>
        </speak>
      SSML
    end
    
    def generate_s3_key(voice_id)
      prefix = case Rails.env
               when 'production'
                 'production/'
               when 'staging'
                 'staging/'
               else
                 'dev/'
               end
      timestamp = Time.now.to_i
      random_string = SecureRandom.hex(8)
      "#{prefix}polly_audio/#{voice_id.downcase}/#{timestamp}_#{random_string}.mp3"
    end
    
    def get_presigned_url(s3_key, expires_in = 3600)
      @s3_service.get_presigned_url(s3_key, expires_in)
    end
  end
end