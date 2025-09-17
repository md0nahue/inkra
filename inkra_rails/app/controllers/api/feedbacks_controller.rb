class Api::FeedbacksController < Api::BaseController
  before_action :authenticate_request!
  
  def create
    feedback = current_user.feedbacks.build(feedback_params)
    
    if feedback.save
      render json: {
        id: feedback.id,
        message: "Thank you for your feedback! We truly appreciate you taking the time to help us improve Inkra.",
        feedback_type: feedback.feedback_type,
        created_at: feedback.created_at
      }, status: :created
    else
      render json: {
        error: "Unable to submit feedback",
        errors: feedback.errors.full_messages
      }, status: :unprocessable_entity
    end
  end
  
  def index
    feedbacks = current_user.feedbacks.recent.limit(10)
    
    render json: {
      feedbacks: feedbacks.map do |feedback|
        {
          id: feedback.id,
          feedback_text: feedback.feedback_text,
          feedback_type: feedback.feedback_type,
          resolved: feedback.resolved,
          created_at: feedback.created_at
        }
      end
    }
  end
  
  private
  
  def feedback_params
    params.require(:feedback).permit(:feedback_text, :feedback_type, :email)
  end
end