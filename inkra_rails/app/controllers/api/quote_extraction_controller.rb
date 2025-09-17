class Api::QuoteExtractionController < Api::BaseController
  def extract
    Rails.logger.info "🟢 QuoteExtraction: Starting extract request"
    
    transcript = params[:transcript]
    orientation = params[:orientation] || 'portrait'
    
    Rails.logger.info "🔵 QuoteExtraction: Request params - transcript length: #{transcript&.length || 0}, orientation: #{orientation}"
    
    if transcript.blank?
      Rails.logger.warn "⚠️ QuoteExtraction: Transcript parameter is blank or missing"
      render json: { error: 'Transcript is required' }, status: :bad_request
      return
    end
    
    unless ['portrait', 'landscape'].include?(orientation)
      Rails.logger.warn "⚠️ QuoteExtraction: Invalid orientation: #{orientation}"
      render json: { error: 'Orientation must be portrait or landscape' }, status: :bad_request
      return
    end
    
    # Add API health check for debugging
    begin
      Rails.logger.info "🔵 QuoteExtraction: Calling GeminiQuoteExtractionService"
      result = GeminiQuoteExtractionService.extract_quotes(transcript, orientation)
      
      Rails.logger.info "🟢 QuoteExtraction: Service returned #{result[:quotes]&.length || 0} quotes"
      Rails.logger.info "🔵 QuoteExtraction: Response structure - quotes: #{result[:quotes]&.length}, searchTerms: #{result[:searchTerms]&.length}, imagePrompts: #{result[:imagePrompts]&.length}"
      
      render json: result, status: :ok
      
    rescue => service_error
      Rails.logger.error "🔴 QuoteExtraction: Service error: #{service_error.class.name} - #{service_error.message}"
      Rails.logger.error "🔴 QuoteExtraction: Service backtrace: #{service_error.backtrace&.first(5)&.join('\n')}"
      raise service_error
    end
    
  rescue => e
    Rails.logger.error "🔴 QuoteExtraction: Controller error: #{e.class.name} - #{e.message}"
    Rails.logger.error "🔴 QuoteExtraction: Full backtrace: #{e.backtrace&.join('\n')}"
    
    error_response = {
      error: 'Quote extraction failed',
      error_type: e.class.name,
      timestamp: Time.current.iso8601
    }
    
    # Add more specific error details in development
    if Rails.env.development?
      error_response[:details] = e.message
      error_response[:backtrace] = e.backtrace&.first(5)
    end
    
    render json: error_response, status: :internal_server_error
  end
end