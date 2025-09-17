module AdminAuthentication
  extend ActiveSupport::Concern

  included do
    before_action :ensure_admin
  end

  private

  def ensure_admin
    unless admin_authenticated?
      render_admin_unauthorized
    end
  end

  def admin_authenticated?
    # Require both authentication and admin privileges
    current_user&.admin? == true
  end

  def render_admin_unauthorized
    if request.format.json?
      render json: { 
        message: 'Admin access required', 
        code: 'ADMIN_ACCESS_REQUIRED',
        details: { reason: 'insufficient_privileges' }
      }, status: :forbidden
    else
      redirect_to root_path, alert: 'Admin access required'
    end
  end
end