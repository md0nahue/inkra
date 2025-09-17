class Api::QuestionsController < Api::BaseController
  before_action :set_question, only: [:skip]
  before_action :set_project, only: [:skip]
  
  def skip
    Rails.logger.debug "=== SKIP_QUESTION DEBUG ==="
    Rails.logger.debug "Project ID: #{@project.id}"
    Rails.logger.debug "Question ID: #{@question.id}"
    Rails.logger.debug "Question text: #{@question.text}"
    
    begin
      # Mark the question as skipped
      @question.update!(skipped: true)
      
      # Update project's last modified timestamp
      @project.update!(last_modified_at: Time.current)
      
      Rails.logger.info "Question #{@question.id} marked as skipped for project #{@project.id}"
      
      render json: {
        message: "Question skipped successfully",
        question_id: @question.id,
        project_id: @project.id,
        skipped: true
      }
      
    rescue => e
      Rails.logger.error "Failed to skip question #{@question.id}: #{e.message}"
      render json: {
        error: "Failed to skip question",
        code: "SKIP_FAILED"
      }, status: :unprocessable_entity
    end
  end
  
  private
  
  def set_question
    @question = Question.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: {
      error: "Question not found",
      code: "QUESTION_NOT_FOUND"
    }, status: :not_found
  end
  
  def set_project
    @project = Project.find(params[:project_id])
  rescue ActiveRecord::RecordNotFound
    render json: {
      error: "Project not found", 
      code: "PROJECT_NOT_FOUND"
    }, status: :not_found
  end
end