class ProfilePicturesController < ApplicationController
  # Serve cached profile pictures
  def show
    filename = params[:filename]
    
    # Security: Only allow jpg files and prevent directory traversal
    # Support both numeric IDs (legacy) and UUID format: user_{id}_{timestamp}.jpg
    # UUID format: 8-4-4-4-12 hex characters, e.g., user_550e8400-e29b-41d4-a716-446655440000_1234567890.jpg
    # Numeric format: user_123_1234567890.jpg
    unless filename.match?(/\Auser_([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}|\d+)_\d+\.jpg\z/i)
      render json: { error: 'Invalid filename' }, status: :bad_request
      return
    end
    
    file_path = Rails.root.join('public', 'cached_profile_pictures', filename)
    
    if File.exist?(file_path)
      send_file file_path, 
                type: 'image/jpeg', 
                disposition: 'inline',
                cache_control: 'public, max-age=31536000' # Cache for 1 year
    else
      # Fallback: try to find the original Google URL for this user
      # Extract user_id (supports both UUID and numeric IDs)
      match = filename.match(/\Auser_([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}|\d+)_\d+\.jpg\z/i)
      if match
        user_id = match[1]
        user = Buyer.find_by(id: user_id) || Seller.find_by(id: user_id)
        if user&.profile_picture&.include?('googleusercontent.com')
          redirect_to user.profile_picture, status: :moved_permanently
        else
          render json: { error: 'Profile picture not found' }, status: :not_found
        end
      else
        render json: { error: 'Invalid filename format' }, status: :bad_request
      end
    end
  end
end
