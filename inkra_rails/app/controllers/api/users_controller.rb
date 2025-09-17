class Api::UsersController < Api::BaseController
  def update_interests
    interests = params[:interests] || []
    
    # Validate that all interests are valid categories
    invalid_interests = interests - User::INTEREST_CATEGORIES
    if invalid_interests.any?
      return render json: { error: "Invalid interests: #{invalid_interests.join(', ')}" }, status: :unprocessable_entity
    end
    
    current_user.update!(interests: interests)
    
    render json: {
      user: {
        id: current_user.id,
        email: current_user.email,
        created_at: current_user.created_at.iso8601,
        interests: current_user.interests
      }
    }
  end
end