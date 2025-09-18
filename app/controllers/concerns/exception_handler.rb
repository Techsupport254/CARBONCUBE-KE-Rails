# app/controllers/concerns/exception_handler.rb
module ExceptionHandler
  extend ActiveSupport::Concern

  included do
    rescue_from ActiveRecord::RecordNotFound do |e|
      json_response({ message: e.message }, :not_found)
    end

    rescue_from ExceptionHandler::AuthenticationError do |e|
      json_response({ message: e.message }, :unauthorized)
    end
    
    rescue_from ExceptionHandler::InvalidToken do |e|
      # Check if the error message indicates token expiration
      if e.message.include?('expired')
        json_response({ 
          message: 'Your session has expired. Please log in again.',
          error_type: 'token_expired',
          expired: true 
        }, :unauthorized)
      else
        json_response({ 
          message: e.message,
          error_type: 'invalid_token'
        }, :unauthorized)
      end
    end

    rescue_from ExceptionHandler::MissingToken do |e|
      json_response({ 
        message: 'Authentication token is required',
        error_type: 'missing_token'
      }, :unauthorized)
    end
  end

  class AuthenticationError < StandardError; end
  class RecordNotFound < StandardError; end
  class InvalidToken < StandardError; end
  class MissingToken < StandardError; end
end
