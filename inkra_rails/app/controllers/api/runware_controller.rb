# frozen_string_literal: true

class Api::RunwareController < Api::BaseController
  before_action :require_authentication

  # POST /api/runware/create_icon
  # Creates a square (1:1) image suitable for icons
  #
  # Parameters:
  #   - prompt (required): Text description of the image to generate
  #   - size (optional): Image size in pixels, must be divisible by 64 (default: 1024)
  #
  # Example request body:
  # {
  #   "prompt": "a glowing nebula shaped like a cat",
  #   "size": 1024
  # }
  def create_icon
    prompt = params[:prompt]
    size = params[:size]&.to_i || 1024

    if prompt.blank?
      render json: { error: 'Prompt is required' }, status: :bad_request
      return
    end

    result = runware_service.create_icon(prompt: prompt, size: size)
    
    if result[:success]
      render json: {
        success: true,
        image_url: result[:image_url],
        task_uuid: result[:task_uuid],
        dimensions: "#{result[:width]}x#{result[:height]}"
      }
    else
      render json: { success: false, error: result[:error] }, status: :unprocessable_entity
    end
  end

  # POST /api/runware/create_portrait
  # Creates a portrait (9:16) image
  #
  # Parameters:
  #   - prompt (required): Text description of the image to generate
  #   - height (optional): Image height in pixels (default: 1344)
  #
  # Example request body:
  # {
  #   "prompt": "astronaut meditating in a field of glowing flowers",
  #   "height": 1344
  # }
  def create_portrait
    prompt = params[:prompt]
    height = params[:height]&.to_i || 1344

    if prompt.blank?
      render json: { error: 'Prompt is required' }, status: :bad_request
      return
    end

    result = runware_service.create_portrait_photo(prompt: prompt, height: height)
    
    if result[:success]
      render json: {
        success: true,
        image_url: result[:image_url],
        task_uuid: result[:task_uuid],
        dimensions: "#{result[:width]}x#{result[:height]}"
      }
    else
      render json: { success: false, error: result[:error] }, status: :unprocessable_entity
    end
  end

  # POST /api/runware/create_tall
  # Creates a tall (6:19) image
  #
  # Parameters:
  #   - prompt (required): Text description of the image to generate
  #   - height (optional): Image height in pixels (default: 1984)
  #
  # Example request body:
  # {
  #   "prompt": "a cascading waterfall of starlight in a cosmic forest",
  #   "height": 1984
  # }
  def create_tall
    prompt = params[:prompt]
    height = params[:height]&.to_i || 1984

    if prompt.blank?
      render json: { error: 'Prompt is required' }, status: :bad_request
      return
    end

    result = runware_service.create_tall_photo(prompt: prompt, height: height)
    
    if result[:success]
      render json: {
        success: true,
        image_url: result[:image_url],
        task_uuid: result[:task_uuid],
        dimensions: "#{result[:width]}x#{result[:height]}"
      }
    else
      render json: { success: false, error: result[:error] }, status: :unprocessable_entity
    end
  end

  # POST /api/runware/create_custom
  # Creates a custom-sized image
  #
  # Parameters:
  #   - prompt (required): Text description of the image to generate
  #   - width (required): Image width in pixels, must be divisible by 64
  #   - height (required): Image height in pixels, must be divisible by 64
  #   - model (optional): Custom model to use (defaults to service default)
  #
  # Example request body:
  # {
  #   "prompt": "a mystical library floating in space",
  #   "width": 1024,
  #   "height": 768
  # }
  def create_custom
    prompt = params[:prompt]
    width = params[:width]&.to_i
    height = params[:height]&.to_i
    model = params[:model]

    if prompt.blank?
      render json: { error: 'Prompt is required' }, status: :bad_request
      return
    end

    if width.nil? || height.nil?
      render json: { error: 'Both width and height are required' }, status: :bad_request
      return
    end

    create_params = { prompt: prompt, width: width, height: height }
    create_params[:model] = model if model.present?

    result = runware_service.create_custom_image(**create_params)
    
    if result[:success]
      render json: {
        success: true,
        image_url: result[:image_url],
        task_uuid: result[:task_uuid],
        dimensions: "#{result[:width]}x#{result[:height]}"
      }
    else
      render json: { success: false, error: result[:error] }, status: :unprocessable_entity
    end
  end

  # GET /api/runware/status
  # Returns the status of the Runware service (API key configured, etc.)
  def status
    begin
      # Try to create a simple test service instance to verify configuration
      test_service = RunwareService.new
      render json: {
        success: true,
        service_available: true,
        message: 'Runware service is configured and ready'
      }
    rescue ArgumentError => e
      render json: {
        success: false,
        service_available: false,
        error: e.message
      }, status: :service_unavailable
    end
  end

  private

  def runware_service
    @runware_service ||= RunwareService.new
  end

  def require_authentication
    unless current_user
      render json: { error: 'Authentication required' }, status: :unauthorized
    end
  end
end