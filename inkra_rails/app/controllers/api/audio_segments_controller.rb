class Api::AudioSegmentsController < Api::BaseController
  include ErrorResponder
  
  before_action :set_project

  # Test Harness Status: ✅ Comprehensive test coverage with happy/sad paths
  def upload_request
    audio_segment = @project.audio_segments.build(audio_segment_params)
    audio_segment.upload_status = 'pending'
    
    if audio_segment.save
      # Generate S3 pre-signed URL using centralized service
      s3_service = S3Service.new(current_user)
      s3_result = s3_service.generate_upload_url(
        record_id: audio_segment.id,
        record_type: 'audio_segment',
        filename: audio_segment.file_name,
        content_type: audio_segment.mime_type,
        expires_in: 3600
      )
      
      render json: {
        audio_segment_id: audio_segment.id,
        upload_url: s3_result[:url],
        expires_at: 1.hour.from_now.iso8601
      }
    else
      render_error(
        audio_segment.errors.full_messages.join(", "),
        "VALIDATION_ERROR",
        :bad_request,
        { field_errors: audio_segment.errors.as_json }
      )
    end
  end

  def upload_complete
    begin
      audio_segment = @project.audio_segments.find(params[:audio_segment_id])
    rescue ActiveRecord::RecordNotFound
      return render_error(
        "Audio segment not found",
        "SEGMENT_NOT_FOUND",
        :not_found
      )
    end
    
    if params[:upload_status] == 'success'
      audio_segment.update!(upload_status: 'success')
      
      # Trigger transcription processing
      TranscriptionService.trigger_transcription_job(audio_segment.id)
      
      render json: {
        message: 'Audio segment processing initiated',
        status: 'processing_started'
      }
    else
      audio_segment.update!(upload_status: 'failed')
      render_error(
        params[:error_message] || 'Upload failed',
        "UPLOAD_FAILED",
        :bad_request
      )
    end
  end

  def playback_url
    begin
      audio_segment = @project.audio_segments.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      return render_error(
        "Audio segment not found",
        "SEGMENT_NOT_FOUND",
        :not_found
      )
    end
    
    # Only allow playback for successfully uploaded segments
    unless audio_segment.upload_status == 'success' || audio_segment.upload_status == 'transcribed'
      return render_error(
        'Audio segment not available for playback',
        "SEGMENT_NOT_AVAILABLE",
        :not_found
      )
    end
    
    begin
      s3_service = S3Service.new(current_user)
      playback_url = s3_service.generate_playback_url(
        record_id: audio_segment.id,
        record_type: 'audio_segment',
        filename: audio_segment.file_name,
        content_type: audio_segment.mime_type,
        expires_in: 3600
      )
      
      render json: {
        playback_url: playback_url,
        expires_at: 1.hour.from_now.iso8601,
        duration: audio_segment.duration_seconds,
        file_name: audio_segment.file_name
      }
    rescue => e
      Rails.logger.error "Failed to generate playback URL: #{e.message}"
      render_error(
        'Unable to generate playback URL',
        "PLAYBACK_URL_ERROR",
        :internal_server_error
      )
    end
  end

  def transcription_details
    begin
      audio_segment = @project.audio_segments.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      return render_error(
        "Audio segment not found",
        "SEGMENT_NOT_FOUND",
        :not_found
      )
    end

    unless audio_segment.transcribed?
      return render_error(
        "Transcription not available for this audio segment",
        "TRANSCRIPTION_NOT_AVAILABLE",
        :bad_request
      )
    end

    # Return the detailed transcription data with word-level timestamps
    transcription_data = audio_segment.transcription_data || {}
    
    render json: {
      words: transcription_data['words'] || [],
      duration: audio_segment.duration_seconds,
      full_text: audio_segment.transcription_text,
      status: 'success'
    }
  end

  private

  def set_project
    unless current_user.present?
      return render json: { error: 'Authentication required to access project data.' }, status: :unauthorized
    end

    @project = current_user.projects.find(params[:project_id] || params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Project not found or you do not have access to it.' }, status: :not_found
  end

  def audio_segment_params
    params.permit(:file_name, :mime_type, :recorded_duration_seconds, :question_id).tap do |permitted|
      permitted[:duration_seconds] = permitted.delete(:recorded_duration_seconds) if permitted[:recorded_duration_seconds]
    end
  end

end
