# app/services/rider_authorize_api_request.rb

class RiderAuthorizeApiRequest
  def initialize(headers = {})
    @headers = headers
  end

  def result
    @rider ||= find_rider
  end

  private

  def find_rider
    return unless decoded_token.present?

    # Check by user ID
    rider_id = decoded_token[:user_id]
    return Rider.find_by(id: rider_id) if rider_id && Rider.exists?(id: rider_id)

    # Check by email
    rider_email = decoded_token[:email]
    return Rider.find_by(email: rider_email) if rider_email && Rider.exists?(email: rider_email)

    # Check by phone number
    rider_phone_number = decoded_token[:phone_number]
    return Rider.find_by(phone_number: rider_phone_number) if rider_phone_number && Rider.exists?(phone_number: rider_phone_number)

    # Check by ID number
    rider_id_number = decoded_token[:id_number]
    return Rider.find_by(id_number: rider_id_number) if rider_id_number && Rider.exists?(id_number: rider_id_number)

    # Raise error if no valid rider is found
    raise ExceptionHandler::InvalidToken, 'Invalid token'
  end

  def decoded_token
    @decoded_token ||= JsonWebToken.decode(http_auth_header)
  end

  def http_auth_header
    if @headers['Authorization'].present?
      @headers['Authorization'].split(' ').last
    else
      raise ExceptionHandler::MissingToken, 'Missing token'
    end
  end
end
