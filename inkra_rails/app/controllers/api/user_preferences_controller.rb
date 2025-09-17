class Api::UserPreferencesController < Api::BaseController
  def show
    render json: { interests: current_user.interests }
  end

  def update
    if current_user.update(preferences_params)
      render json: { interests: current_user.interests, message: "Preferences updated successfully." }
    else
      render json: { errors: current_user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def preferences_params
    params.require(:user_preferences).permit(interests: [])
  end
end
