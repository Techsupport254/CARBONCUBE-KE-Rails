# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base  
  include ExceptionHandler

  # Protect from CSRF for non-API endpoints
  protect_from_forgery with: :exception, unless: -> { request.format.json? }

  # Skip CSRF protection globally for API requests (in case you're building an API)
  skip_before_action :verify_authenticity_token, raise: false, if: -> { request.format.json? }

    # Optionally, you can uncomment the following for authentication
  # before_action :authenticate_request # Uncomment if needed for authentication

  attr_reader :current_user

  def home
    render json: { message: "API is up and running" }, status: :ok
  end

  def missing_file
    # Return a 404 for missing static files like images
    render json: { error: 'File not found' }, status: :not_found
  end

  private

  def authenticate_request
    @current_user = AuthorizeApiRequest.new(request.headers).result
    render json: { error: 'Not Authorized' }, status: 401 unless @current_user
  end

  def json_response(object, status = :ok)
    render json: object, status: status
  end
end
