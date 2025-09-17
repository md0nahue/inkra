class PollyGenerationJob < ApplicationJob
  queue_as :default
  
  def perform(question_id, voice_id: 'Joanna', speech_rate: 100)
    Rails.logger.debug "\n🎙️🚀 POLLY GENERATION JOB STARTED"
    Rails.logger.debug "━" * 50
    Rails.logger.debug "🆔 Question ID: #{question_id}"
    Rails.logger.debug "🎙️ Voice ID: #{voice_id}"
    Rails.logger.debug "⏱️ Speech Rate: #{speech_rate}"
    
    question = Question.find_by(id: question_id)
    unless question
      Rails.logger.warn "PollyGenerationJob: Question with id #{question_id} not found, skipping job"
      return
    end
    
    Rails.logger.debug "📝 Question Text: \"#{question.text}\""
    Rails.logger.debug "📁 Section: #{question.section.title}"
    Rails.logger.debug "📚 Chapter: #{question.section.chapter.title}"
    
    project = question.section.chapter.project
    
    # Skip if project is not a speech interview
    return unless project.is_speech_interview
    
    # Skip if audio already exists and is completed
    if question.polly_audio_clip&.completed?
      Rails.logger.info "Polly audio already exists for question #{question_id}"
      return
    end
    
    # Create or find the polly audio clip record
    audio_clip = question.polly_audio_clip || question.create_polly_audio_clip!(
      voice_id: voice_id,
      speech_rate: speech_rate,
      status: 'pending'
    )
    
    # Update status to generating
    audio_clip.update!(status: 'generating')
    
    begin
      # Generate speech using Polly service
      Rails.logger.debug "🎙️ Calling AWS Polly service..."
      polly_service = Aws::PollyService.new(project.user)
      result = polly_service.generate_speech(
        text: question.text,
        voice_id: voice_id,
        speech_rate: speech_rate
      )
      
      Rails.logger.debug "🗝 Generated S3 Key: #{result[:s3_key]}"
      
      # Update the audio clip with the S3 key
      audio_clip.update!(
        s3_key: result[:s3_key],
        status: 'completed'
      )
      
      Rails.logger.info "✅ Successfully generated Polly audio for question #{question_id}"
      Rails.logger.debug "   🗝 Final S3 Key: #{audio_clip.s3_key}"
      Rails.logger.debug "━" * 50
      
    rescue StandardError => e
      Rails.logger.error "❌ Failed to generate Polly audio for question #{question_id}: #{e.message}"
      Rails.logger.debug "━" * 50
      audio_clip.update!(
        status: 'failed',
        error_message: e.message
      )
      raise
    end
  end
end