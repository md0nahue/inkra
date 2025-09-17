class Api::SpeakersController < Api::BaseController
  before_action :set_speaker, only: [:show, :update, :destroy]
  
  def index
    @speakers = current_user.speakers.order(created_at: :desc)
    render json: @speakers
  end
  
  def show
    render json: @speaker
  end
  
  def create
    @speaker = current_user.speakers.build(speaker_params)
    
    if @speaker.save
      render json: @speaker, status: :created
    else
      render json: { errors: @speaker.errors.full_messages }, status: :unprocessable_entity
    end
  end
  
  def update
    if @speaker.update(speaker_params)
      render json: @speaker
    else
      render json: { errors: @speaker.errors.full_messages }, status: :unprocessable_entity
    end
  end
  
  def destroy
    @speaker.destroy
    head :no_content
  end
  
  private
  
  def set_speaker
    @speaker = current_user.speakers.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Speaker not found' }, status: :not_found
  end
  
  def speaker_params
    params.require(:speaker).permit(:name, :email, :phone_number, :pronoun, :notes)
  end
end