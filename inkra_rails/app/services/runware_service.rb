# frozen_string_literal: true

# ==============================================================================
# RunwareService Class
#
# @description
#   A Ruby service for the Runware Text-to-Image REST API integrated into Rails.
#   This service handles authentication, API request construction, and response
#   parsing for generating images based on textual prompts.
#
# @usage
#   # Generate a square icon (1:1)
#   runware = RunwareService.new
#   icon_url = runware.create_icon(prompt: "a glowing nebula shaped like a cat")
#   
#   # Generate a portrait photo (9:16)
#   portrait_url = runware.create_portrait_photo(prompt: "astronaut meditating in a field of glowing flowers")
#   
#   # Generate a tall photo (6:19)  
#   tall_url = runware.create_tall_photo(prompt: "a lone monolith on a distant planet, two moons in the sky")
#
# ==============================================================================
class RunwareService
  include HTTParty

  # The base URI for the Runware v1 REST API.
  base_uri 'https://api.runware.ai/v1'

  # The overall aesthetic prompt to be appended to every request.
  # This defines the "Cosmic Lofi" look and feel.
  COSMIC_LOFI_AESTHETIC = [
    'Cosmic Lofi aesthetic',
    'calm, introspective, and magical digital space',
    'a quiet corner of the universe at midnight',
    'sophisticated and modern with depth and softness',
    'deep near-black blues and purples',
    'muted, luminous pastel highlights like distant nebulae or soft aurora lights',
    'serene, cinematic',
    '4k, high detail'
  ].join(', ').freeze

  # The negative prompt to steer the AI away from undesired elements.
  NEGATIVE_AESTHETIC = [
    'pure black',
    'harsh lighting',
    'oversaturated colors',
    'bright jarring colors',
    'chaotic composition',
    'blurry, low quality, pixelated',
    'text, watermark, signature, username'
  ].join(', ').freeze
  
  # A capable default model that works well for a variety of styles.
  # HiDream-I1 Full is the highest quality HiDream model with sharp detail,
  # accurate prompts, full LoRA compatibility, and is fully uncensored.
  DEFAULT_MODEL = 'hidream:i1-full'.freeze

  def initialize(api_key: ENV['RUNWARE_API_KEY'])
    raise ArgumentError, 'RUNWARE_API_KEY environment variable not set.' if api_key.nil? || api_key.empty?

    @api_key = api_key

    # Set default headers for all requests made by this class instance.
    self.class.headers(
      'Authorization' => "Bearer #{@api_key}",
      'Content-Type' => 'application/json'
    )
  end

  # ============================================================================
  # Public Methods
  # ============================================================================

  # Generates a square image (1:1 aspect ratio), ideal for icons.
  #
  # @param prompt [String] The main subject of the image.
  # @param size [Integer] The width and height of the image in pixels. Must be divisible by 64.
  # @return [Hash] Response containing image URL or error details
  def create_icon(prompt:, size: 1024)
    Rails.logger.info("Starting icon generation for prompt: '#{prompt}'")
    
    unless size % 64 == 0
      Rails.logger.error("Image size must be divisible by 64. Received: #{size}")
      return { success: false, error: "Image size must be divisible by 64" }
    end

    create_image_with_polling(
      prompt: prompt,
      width: size,
      height: size
    )
  end

  # Generates a portrait image (9:16 aspect ratio).
  #
  # @param prompt [String] The main subject of the image.
  # @param height [Integer] The height of the image. Width will be calculated to match the 9:16 aspect ratio and rounded to the nearest multiple of 64.
  # @return [Hash] Response containing image URL or error details
  def create_portrait_photo(prompt:, height: 1344)
    Rails.logger.info("Starting 9:16 portrait generation for prompt: '#{prompt}'")
    
    # Calculate width for a 9:16 aspect ratio and ensure it's divisible by 64.
    width = calculate_dimension(height * 9.0 / 16.0)

    create_image_with_polling(
      prompt: prompt,
      width: width,
      height: height
    )
  end

  # Generates a very tall image (6:19 aspect ratio).
  # Note: 6:19 is an unconventional ratio. This method creates an image that approximates it.
  #
  # @param prompt [String] The main subject of the image.
  # @param height [Integer] The height of the image. Width will be calculated to match the 6:19 aspect ratio and rounded to the nearest multiple of 64.
  # @return [Hash] Response containing image URL or error details
  def create_tall_photo(prompt:, height: 1984)
    Rails.logger.info("Starting 6:19 tall photo generation for prompt: '#{prompt}'")
    
    # Calculate width for a 6:19 aspect ratio and ensure it's divisible by 64.
    width = calculate_dimension(height * 6.0 / 19.0)

    create_image_with_polling(
      prompt: prompt,
      width: width,
      height: height
    )
  end

  # Generic method for creating images with custom dimensions
  #
  # @param prompt [String] The main subject of the image.
  # @param width [Integer] Image width (must be divisible by 64).
  # @param height [Integer] Image height (must be divisible by 64).
  # @param model [String] Optional model override.
  # @return [Hash] Response containing image URL or error details
  def create_custom_image(prompt:, width:, height:, model: DEFAULT_MODEL)
    Rails.logger.info("Starting custom image generation: #{width}x#{height} for prompt: '#{prompt}'")
    
    unless width % 64 == 0 && height % 64 == 0
      Rails.logger.error("Image dimensions must be divisible by 64. Received: #{width}x#{height}")
      return { success: false, error: "Image dimensions must be divisible by 64" }
    end

    create_image_with_polling(
      prompt: prompt,
      width: width,
      height: height,
      model: model
    )
  end

  private

  # ============================================================================
  # Private Helper Methods
  # ============================================================================

  # Core method to submit an image generation task and poll for the result.
  # The Runware REST API is synchronous and returns the result directly.
  #
  # @param prompt [String] The user's prompt.
  # @param width [Integer] Image width.
  # @param height [Integer] Image height.
  # @param model [String] The model to use.
  # @return [Hash] Response with success status and either image_url or error
  def create_image_with_polling(prompt:, width:, height:, model: DEFAULT_MODEL)
    task_uuid = SecureRandom.uuid
    full_prompt = "#{prompt}, #{COSMIC_LOFI_AESTHETIC}"

    payload = [{
      taskType: 'imageInference',
      taskUUID: task_uuid,
      positivePrompt: full_prompt,
      negativePrompt: NEGATIVE_AESTHETIC,
      width: width,
      height: height,
      model: model,
      steps: 30, # A good balance of quality and speed.
      numberResults: 1
    }]

    Rails.logger.debug("Submitting task #{task_uuid} with payload: #{payload.to_json}")

    begin
      response = self.class.post('/', body: payload.to_json)

      unless response.success?
        Rails.logger.error("HTTP Error: #{response.code} - #{response.message}")
        Rails.logger.error("Response Body: #{response.body}")
        return { success: false, error: "HTTP Error: #{response.code} - #{response.message}" }
      end

      parsed_response = response.parsed_response
      Rails.logger.debug("Received response: #{parsed_response.to_json}")

      # Check for API-level errors
      if parsed_response['error']
        Rails.logger.error("API Error: #{parsed_response['error']}")
        return { success: false, error: parsed_response['error'] }
      end

      # Find the result corresponding to our task UUID
      task_result = parsed_response['data']&.find { |item| item['taskUUID'] == task_uuid }

      if task_result && task_result['imageURL']
        Rails.logger.info("Successfully generated image for task #{task_uuid}.")
        return { 
          success: true, 
          image_url: task_result['imageURL'],
          task_uuid: task_uuid,
          width: width,
          height: height
        }
      else
        Rails.logger.error("API response did not contain a valid image URL for task #{task_uuid}.")
        Rails.logger.debug("Full response data: #{parsed_response['data']}")
        return { success: false, error: "API response did not contain a valid image URL" }
      end

    rescue HTTParty::Error, SocketError => e
      Rails.logger.error("Network or HTTParty error: #{e.message}")
      return { success: false, error: "Network error: #{e.message}" }
    rescue StandardError => e
      Rails.logger.error("Unexpected error in Runware service: #{e.message}")
      return { success: false, error: "Unexpected error: #{e.message}" }
    end
  end
  
  # Helper to round a dimension to the nearest multiple of 64, as required by the API.
  #
  # @param value [Float] The calculated dimension.
  # @return [Integer] The dimension rounded to the nearest multiple of 64.
  def calculate_dimension(value)
    (value / 64.0).round * 64
  end
end