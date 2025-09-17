class Api::PollyVoicesController < Api::BaseController
  include ErrorResponder
  
  # Make the index action publicly accessible (no authentication required)
  skip_before_action :authenticate_api_request!, only: [:index]

  def index
    begin
      polly_service = Aws::PollyService.new # No user needed for listing voices
      voices = polly_service.list_english_voices.map do |voice|
        {
          id: voice[:id],
          name: voice[:name],
          gender: voice[:gender],
          neural: voice[:neural],
          language_code: voice[:language_code],
          demo_url: "https://#{ENV['AWS_S3_BUCKET']}.s3.us-east-1.amazonaws.com/inkra_voice_welcomes/#{voice[:id].downcase}_inkra_welcome.mp3"
        }
      end
      render json: {
        voices: voices,
        default_voice_id: Aws::PollyService::DEFAULT_VOICE,
        supported_speech_rates: [70, 80, 90, 100, 110, 120, 130, 140, 150, 160, 170, 180, 190, 200] # Example rates
      }
    rescue => e
      Rails.logger.error "Failed to fetch Polly voices for index: #{e.message}"
      render_error("Failed to fetch voices.", "VOICE_FETCH_FAILED", :internal_server_error)
    end
  end

  def generate_demo
    voice_id = params[:id]
    service = Aws::PollyService.new # Use the main PollyService

    # Find the voice configuration in ENGLISH_VOICES
    voice_config = Aws::PollyService::ENGLISH_VOICES.find { |v| v[:id] == voice_id }
    
    unless voice_config
      return render_not_found("Voice with ID '#{voice_id}' not found in English voices list.")
    end

    Rails.logger.info "🎤 Generating demo for voice: #{voice_id}"

    begin
      # Use a standard demo phrase
      demo_text = "Hi there! This is a sample of my voice. I can help bring your story to life with natural, expressive narration."
      
      # Pass the correct engine type (neural or standard)
      engine_type = voice_config[:neural] ? 'neural' : 'standard'

      result = service.generate_speech(
        text: demo_text,
        voice_id: voice_id,
        speech_rate: 100, # Default demo rate
        language_code: voice_config[:language_code], # Use correct language code from config
        engine: engine_type # Ensure the correct engine is passed
      )

      s3_key = result[:s3_key]
      demo_url = service.get_presigned_url(s3_key) # Generate presigned URL for playback

      Rails.logger.info "🎤 Demo generated for #{voice_id}"
      render json: { demo_url: demo_url }, status: :ok
    rescue Aws::Polly::Errors::ServiceError => e
      Rails.logger.error "Polly service error generating demo for #{voice_id}: #{e.message}"
      render_error("Polly service error: #{e.message}", "POLLY_SERVICE_ERROR", :bad_request)
    rescue => e
      Rails.logger.error "🚨 Failed to generate demo for #{voice_id}: #{e.message}"
      render_error("Failed to generate demo clip. Error: #{e.message}", "DEMO_GENERATION_FAILED", :internal_server_error)
    end
  end
end