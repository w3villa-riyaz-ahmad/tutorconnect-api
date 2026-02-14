class ApplicationController < ActionController::API
  rescue_from ActiveRecord::RecordNotFound, with: :not_found
  rescue_from ActiveRecord::RecordInvalid, with: :unprocessable_entity_error
  rescue_from ActionController::ParameterMissing, with: :bad_request

  private

  # Extract current user from JWT in Authorization header
  def current_user
    @current_user ||= begin
      token = extract_token
      return nil unless token

      payload = JwtService.decode(token)
      return nil unless payload && payload[:type] == "access"

      User.find_by(id: payload[:user_id])
    end
  end

  # Require authentication — returns 401 if not logged in
  def authenticate!
    unless current_user
      render json: { error: "You must be logged in to access this resource" }, status: :unauthorized
    end
  end

  # Require admin role — returns 403 if not admin
  def admin_only!
    authenticate!
    return if performed? # already rendered 401

    unless current_user&.admin?
      render json: { error: "Admin access required" }, status: :forbidden
    end
  end

  # Require verified email
  def require_verified!
    authenticate!
    return if performed?

    unless current_user&.verified?
      render json: { error: "Please verify your email address first" }, status: :forbidden
    end
  end

  def extract_token
    header = request.headers["Authorization"]
    header&.split(" ")&.last
  end

  def not_found(exception)
    render json: { error: exception.message }, status: :not_found
  end

  def unprocessable_entity_error(exception)
    render json: { error: exception.record.errors.full_messages }, status: :unprocessable_entity
  end

  def bad_request(exception)
    render json: { error: exception.message }, status: :bad_request
  end
end

