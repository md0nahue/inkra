module ErrorResponder
  extend ActiveSupport::Concern

  included do
    rescue_from ActiveRecord::RecordNotFound, with: :handle_record_not_found
    rescue_from ActiveRecord::RecordInvalid, with: :handle_record_invalid
    rescue_from ActionController::ParameterMissing, with: :handle_parameter_missing
    rescue_from StandardError, with: :handle_internal_server_error
    rescue_from ActionController::UnpermittedParameters, with: :handle_unpermitted_parameters
  end

  private

  def render_error(message, code, status, details = {})
    render json: {
      message: message,
      code: code,
      details: details
    }, status: status
  end

  def handle_record_not_found(exception)
    render_error(
      "Resource not found",
      "NOT_FOUND",
      :not_found,
      { resource: exception.model }
    )
  end

  def handle_record_invalid(exception)
    render_error(
      exception.record.errors.full_messages.join(", "),
      "VALIDATION_ERROR",
      :bad_request,
      { field_errors: exception.record.errors.as_json }
    )
  end

  def handle_parameter_missing(exception)
    render_error(
      "Required parameter missing: #{exception.param}",
      "MISSING_PARAMETER",
      :bad_request,
      { parameter: exception.param }
    )
  end

  def handle_internal_server_error(exception)
    Rails.logger.error "Internal Server Error: #{exception.message}"
    Rails.logger.error exception.backtrace.join("\n")
    
    render_error(
      "An internal error occurred",
      "INTERNAL_SERVER_ERROR",
      :internal_server_error,
      Rails.env.development? ? { exception: exception.message, backtrace: exception.backtrace.first(10) } : {}
    )
  end

  def handle_unpermitted_parameters(exception)
    render_error(
      "Unpermitted parameters provided: #{exception.params.join(', ')}",
      "UNPERMITTED_PARAMETERS",
      :bad_request,
      { unpermitted_params: exception.params }
    )
  end

  def validate_project_ownership!(project)
    unless project
      render_error(
        "Project not found",
        "PROJECT_NOT_FOUND",
        :not_found
      )
      return false
    end
    true
  end

  def validate_audio_segment!(audio_segment, project_id)
    unless audio_segment
      render_error(
        "Audio segment not found",
        "AUDIO_SEGMENT_NOT_FOUND",
        :not_found
      )
      return false
    end

    unless audio_segment.project_id.to_s == project_id.to_s
      render_error(
        "Audio segment does not belong to this project",
        "UNAUTHORIZED_ACCESS",
        :forbidden
      )
      return false
    end

    true
  end

  # Additional helper methods for common API errors
  def render_unauthorized(message = "Unauthorized access")
    render_error(message, "UNAUTHORIZED", :unauthorized)
  end

  def render_forbidden(message = "Access forbidden")
    render_error(message, "FORBIDDEN", :forbidden)
  end

  def render_unprocessable_entity(message, details = {})
    render_error(message, "UNPROCESSABLE_ENTITY", :unprocessable_entity, details)
  end

  def render_bad_request(message, details = {})
    render_error(message, "BAD_REQUEST", :bad_request, details)
  end

  def render_not_found(message = "Resource not found")
    render_error(message, "NOT_FOUND", :not_found)
  end

  def render_service_unavailable(message = "Service temporarily unavailable")
    render_error(message, "SERVICE_UNAVAILABLE", :service_unavailable)
  end
end