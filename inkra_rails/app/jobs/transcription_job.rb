class TranscriptionJob < ApplicationJob
  queue_as :default

  def perform(audio_segment_id)
    Rails.logger.info "Starting transcription job for audio segment #{audio_segment_id}"
    
    # Delegate to TranscriptionService for actual processing
    result = TranscriptionService.process_transcription(audio_segment_id)
    
    if result[:success]
      Rails.logger.info "Transcription job completed successfully for audio segment #{audio_segment_id}"
      
      # Get the audio segment and project
      audio_segment = AudioSegment.find_by(id: audio_segment_id)
      unless audio_segment
        Rails.logger.warn "TranscriptionJob: AudioSegment with id #{audio_segment_id} not found during follow-up processing"
        return result
      end
      project = audio_segment.project
      
      # Trigger follow-up question generation if transcription was successful
      if audio_segment.question.present? && audio_segment.transcription_text.present?
        GenerateFollowupQuestionsJob.perform_later(audio_segment_id)
        Rails.logger.info "Triggered follow-up question generation for audio segment #{audio_segment_id}"
      end
      
      # Check if all audio segments for this project are now transcribed
      # Use reliable count check instead of iterating over all segments to avoid race condition
      total_segments = project.audio_segments.count
      transcribed_segments = project.audio_segments.where(upload_status: 'transcribed').count
      
      if total_segments == transcribed_segments
        Rails.logger.info "All #{total_segments} segments transcribed for project #{project.id}, enqueuing FinalizeTranscriptJob."
        FinalizeTranscriptJob.perform_later(project.id)
      end
    else
      Rails.logger.error "Transcription job failed for audio segment #{audio_segment_id}: #{result[:error]}"
    end
    
    result
  rescue => e
    Rails.logger.error "Transcription job error for audio segment #{audio_segment_id}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise e
  end
end