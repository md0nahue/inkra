class Api::PollyAudioController < Api::BaseController
  before_action :set_project, except: [:generate_questions, :voices]

  # Generate Polly audio for all questions in a project
  def generate_all
    tracker = PerformanceTracker.instance
    session_id = "api_generate_all_#{@project&.id || 'unknown'}_#{Time.current.to_i}"
    tracker.start_session(session_id)

    unless @project.is_speech_interview
      tracker.track_event('validation_failed', { reason: 'not_speech_interview' })
      render json: { 
        project_id: @project.id,
        error: 'Project is not configured for speech interviews' 
      }, status: :bad_request
      return
    end

    voice_id = params[:voice_id] || 'Matthew'
    speech_rate = params[:speech_rate]&.to_i || 100
    
    # Update project with voice settings
    tracker.track_event('update_project_settings', { voice_id: voice_id, speech_rate: speech_rate }) do
      @project.update(voice_id: voice_id, speech_rate: speech_rate)
    end

    begin
      result = tracker.track_event('polly_generation_service', { 
        project_id: @project.id, 
        voice_id: voice_id, 
        speech_rate: speech_rate 
      }) do
        service = PollyAudioGenerationService.new(@project, voice_id: voice_id, speech_rate: speech_rate)
        service.generate_all_question_audio
      end

      tracker.end_session

      render json: {
        project_id: @project.id,
        voice_id: voice_id,
        speech_rate: speech_rate,
        generation_summary: result,
        generated_at: Time.current.iso8601,
        performance_session_id: session_id
      }
    rescue => e
      Rails.logger.error "Polly audio generation failed for project #{@project.id}: #{e.message}"
      tracker.track_event('generation_error', { error: e.message })
      tracker.end_session
      
      render json: { 
        project_id: @project.id,
        error: "Failed to generate audio: #{e.message}",
        performance_session_id: session_id
      }, status: :internal_server_error
    end
  end

  # Generate audio for questions that don't have it yet
  def generate_missing
    unless @project.is_speech_interview
      render json: { 
        project_id: @project.id,
        error: 'Project is not configured for speech interviews' 
      }, status: :bad_request
      return
    end

    voice_id = params[:voice_id] || 'Matthew'
    speech_rate = params[:speech_rate]&.to_i || 100
    
    # Update project with voice settings
    @project.update(voice_id: voice_id, speech_rate: speech_rate)

    begin
      service = PollyAudioGenerationService.new(@project, voice_id: voice_id, speech_rate: speech_rate)
      success_count = service.generate_missing_question_audio

      render json: {
        project_id: @project.id,
        voice_id: voice_id,
        speech_rate: speech_rate,
        generated_count: success_count,
        generated_at: Time.current.iso8601
      }
    rescue => e
      Rails.logger.error "Missing Polly audio generation failed for project #{@project.id}: #{e.message}"
      render json: { 
        project_id: @project.id,
        error: "Failed to generate missing audio: #{e.message}" 
      }, status: :internal_server_error
    end
  end

  # Update voice settings and regenerate audio as needed
  def update_voice_settings
    unless @project.is_speech_interview
      render json: { 
        project_id: @project.id,
        error: 'Project is not configured for speech interviews' 
      }, status: :bad_request
      return
    end

    voice_id = params[:voice_id]
    speech_rate = params[:speech_rate]&.to_i

    if voice_id.blank? || speech_rate.blank?
      render json: { 
        project_id: @project.id,
        error: 'Voice ID and speech rate are required' 
      }, status: :bad_request
      return
    end
    
    # Update project with voice settings
    @project.update(voice_id: voice_id, speech_rate: speech_rate)

    begin
      service = PollyAudioGenerationService.new(@project, voice_id: voice_id, speech_rate: speech_rate)
      regenerated_count = service.update_voice_settings(voice_id, speech_rate)

      render json: {
        project_id: @project.id,
        voice_id: voice_id,
        speech_rate: speech_rate,
        regenerated_count: regenerated_count,
        updated_at: Time.current.iso8601
      }
    rescue => e
      Rails.logger.error "Voice settings update failed for project #{@project.id}: #{e.message}"
      render json: { 
        project_id: @project.id,
        error: "Failed to update voice settings: #{e.message}" 
      }, status: :internal_server_error
    end
  end

  # Get generation status for a project
  def status
    unless @project.is_speech_interview
      render json: { 
        project_id: @project.id,
        error: 'Project is not configured for speech interviews' 
      }, status: :bad_request
      return
    end

    begin
      service = PollyAudioGenerationService.new(@project)
      status_info = service.generation_status
      cost_estimate = service.estimate_cost

      render json: {
        project_id: @project.id,
        status: status_info,
        cost_estimate: cost_estimate,
        checked_at: Time.current.iso8601
      }
    rescue => e
      Rails.logger.error "Status check failed for project #{@project.id}: #{e.message}"
      render json: { 
        project_id: @project.id,
        error: "Failed to get status: #{e.message}" 
      }, status: :internal_server_error
    end
  end

  # Generate audio for specific questions
  def generate_questions
    question_ids = params[:question_ids] || []
    voice_id = params[:voice_id] || 'Matthew'
    speech_rate = params[:speech_rate]&.to_i || 100

    if question_ids.empty?
      render json: { error: 'Question IDs are required' }, status: :bad_request
      return
    end

    # Verify user has access to all questions
    user_question_ids = current_user.projects.joins(:questions).where(questions: { id: question_ids }).pluck('questions.id')
    if user_question_ids.length != question_ids.length
      render json: { error: 'Some questions not found or access denied' }, status: :forbidden
      return
    end

    begin
      results = PollyAudioGenerationService.batch_generate(question_ids, voice_id: voice_id, speech_rate: speech_rate)

      success_count = results.count { |r| r[:status] == 'success' }
      error_count = results.count { |r| r[:status] == 'error' }

      render json: {
        voice_id: voice_id,
        speech_rate: speech_rate,
        results: results,
        summary: {
          total: results.length,
          success: success_count,
          errors: error_count
        },
        generated_at: Time.current.iso8601
      }
    rescue => e
      Rails.logger.error "Batch audio generation failed: #{e.message}"
      render json: { error: "Failed to generate audio: #{e.message}" }, status: :internal_server_error
    end
  end

  # List available Polly voices
  def voices
    begin
      polly_service = Aws::PollyService.new
      voices = polly_service.list_english_voices

      render json: {
        voices: voices,
        default_voice: Aws::PollyService::DEFAULT_VOICE,
        fetched_at: Time.current.iso8601
      }
    rescue => e
      Rails.logger.error "Failed to fetch Polly voices: #{e.message}"
      render json: { error: "Failed to fetch voices: #{e.message}" }, status: :internal_server_error
    end
  end

  # Clean up failed audio clips
  def cleanup_failed
    unless @project.is_speech_interview
      render json: { 
        project_id: @project.id,
        error: 'Project is not configured for speech interviews' 
      }, status: :bad_request
      return
    end

    begin
      service = PollyAudioGenerationService.new(@project)
      cleanup_count = service.cleanup_failed_clips

      render json: {
        project_id: @project.id,
        cleaned_up_count: cleanup_count,
        cleaned_at: Time.current.iso8601
      }
    rescue => e
      Rails.logger.error "Cleanup failed for project #{@project.id}: #{e.message}"
      render json: { 
        project_id: @project.id,
        error: "Failed to cleanup: #{e.message}" 
      }, status: :internal_server_error
    end
  end

  private

  def set_project
    unless current_user.present?
      return render json: { 
        requested_project_id: params[:id],
        error: 'Authentication required to access project data.' 
      }, status: :unauthorized
    end

    @project = current_user.projects.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { 
      requested_project_id: params[:id],
      error: 'Project not found or you do not have access to it.' 
    }, status: :not_found
  end
end