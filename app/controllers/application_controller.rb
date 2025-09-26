# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base  
  include ExceptionHandler

  # Protect from CSRF for non-API endpoints
  protect_from_forgery with: :exception, unless: -> { request.format.json? }

  # Skip CSRF protection globally for API requests (in case you're building an API)
  skip_before_action :verify_authenticity_token, raise: false, if: -> { request.format.json? }
  
  # Add query timeout protection for database operations
  around_action :set_query_timeout

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

  def set_query_timeout
    # Set a reasonable query timeout for production
    ActiveRecord::Base.connection.execute("SET statement_timeout = '30s'")
    yield
  ensure
    # Reset to default timeout
    ActiveRecord::Base.connection.execute("SET statement_timeout = '60s'")
  end

  def authenticate_request
    @current_user = AuthorizeApiRequest.new(request.headers).result
    render json: { error: 'Not Authorized' }, status: 401 unless @current_user
  end

  def json_response(object, status = :ok)
    render json: object, status: status
  end
end
