class FinalizeTranscriptJob < ApplicationJob
  queue_as :default

  def perform(project_id)
    Rails.logger.info "Starting transcript finalization for project #{project_id}"
    
    # Generate both structured and plaintext content in a single job
    result = TranscriptContentAssemblerService.finalize_transcript(project_id)
    
    if result[:success]
      Rails.logger.info "Transcript finalization completed for project #{project_id}"
    else
      Rails.logger.error "Transcript finalization failed for project #{project_id}: #{result[:error]}"
    end
    
    result
  rescue => e
    Rails.logger.error "Transcript finalization job error for project #{project_id}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise e
  end
end