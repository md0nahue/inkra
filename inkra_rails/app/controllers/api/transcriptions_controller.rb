class Api::TranscriptionsController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :authenticate_request!
  
  def create
    # Handle audio file upload for topic transcription
    unless params[:file].present?
      render json: { error: "No audio file provided" }, status: :bad_request
      return
    end
    
    audio_file = params[:file]
    
    # Validate file type - accept audio files and common formats that might not be detected properly
    unless audio_file.content_type&.start_with?('audio/') || 
           audio_file.original_filename&.match?(/\.(m4a|mp3|wav|ogg|aac|mp4|mov)$/i) ||
           audio_file.content_type&.include?('application/octet-stream')
      render json: { error: "Invalid file type. Please upload an audio file. Got: #{audio_file.content_type}" }, status: :bad_request
      return
    end
    
    # Validate file size (max 25MB)
    max_size = 25.megabytes
    if audio_file.size > max_size
      render json: { error: "File too large. Maximum size is 25MB." }, status: :bad_request
      return
    end
    
    begin
      # Create a temporary file for transcription
      temp_file = Tempfile.new(['voice_input', File.extname(audio_file.original_filename)])
      temp_file.binmode
      temp_file.write(audio_file.read)
      temp_file.close
      
      # Use TranscriptionService to transcribe the audio with Groq
      transcription_service = TranscriptionService.new
      transcribed_text = transcription_service.transcribe_audio(temp_file.path)
      
      # Clean up temp file
      temp_file.unlink
      
      if transcribed_text.present?
        render json: { 
          transcription: transcribed_text,
          success: true 
        }, status: :ok
      else
        render json: { 
          error: "Could not transcribe the audio. Please try again.",
          success: false 
        }, status: :unprocessable_entity
      end
      
    rescue => e
      Rails.logger.error "Voice input transcription error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      # Clean up temp file if it exists
      temp_file&.unlink rescue nil
      
      render json: { 
        error: "Failed to process audio: #{e.message}",
        success: false 
      }, status: :internal_server_error
    end
  end
end