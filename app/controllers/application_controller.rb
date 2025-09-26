class ApplicationController < ActionController::Base
  include ActionController::MimeResponds
  protect_from_forgery with: :exception, unless: -> { request.format.json? }
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  def favicon
    head :ok
  end

  private

  def require_owner!
    authenticate_user!
    unless current_actor&.owner?
      respond_to do |format|
        format.html { head :forbidden }
        format.json { render json: { error: "forbidden" }, status: :forbidden }
      end
    end
  end

  def reject_suspended!
    authenticate_user!
    if current_user&.respond_to?(:suspended_now?) && current_user.suspended_now?
      sign_out current_actor
      redirect_to new_user_session_path, alert: "Your account is suspended."
    end
  end

  # The authenticated user (actor) regardless of impersonation state.
  def current_actor
    warden.user(scope: :user)
  end
  helper_method :current_actor

  # Whether the actor is impersonating another user.
  def impersonating?
    session[:impersonated_user_id].present?
  end
  helper_method :impersonating?

  # The impersonated user, if any.
  def impersonated_user
    @impersonated_user ||= User.find_by(id: session[:impersonated_user_id]) if session[:impersonated_user_id]
  end
  helper_method :impersonated_user

  # Override current_user to return the impersonated user when present (view-only).
  def current_user
    impersonated_user || current_actor
  end

  # Block non-GET writes while impersonating (view-only mode).
  def block_writes_if_impersonating
    return unless impersonating?
    return if request.get? || request.head?
    # Allow owner namespace to manage impersonation and admin actions
    return if controller_path.start_with?("owner/")
    respond_to do |format|
      format.html { render plain: "Impersonation is view-only.", status: :forbidden }
      format.json { render json: { error: "impersonation_view_only" }, status: :forbidden }
    end
  end
  before_action :block_writes_if_impersonating
end
