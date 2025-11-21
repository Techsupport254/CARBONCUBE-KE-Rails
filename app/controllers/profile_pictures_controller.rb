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
      # Set proper headers to prevent CORB (Cross-Origin Read Blocking) issues
      headers['Content-Type'] = 'image/jpeg'
      headers['X-Content-Type-Options'] = 'nosniff'
      headers['Access-Control-Allow-Origin'] = '*' # Allow cross-origin requests
      headers['Cache-Control'] = 'public, max-age=31536000' # Cache for 1 year
      
      send_file file_path, 
                type: 'image/jpeg', 
                disposition: 'inline'
    else
      # Fallback: try to re-cache or find the original Google URL for this user
      # Extract user_id (supports both UUID and numeric IDs)
      match = filename.match(/\Auser_([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}|\d+)_\d+\.jpg\z/i)
      if match
        user_id = match[1]
        user = Buyer.find_by(id: user_id) || Seller.find_by(id: user_id)
        
        if user
          # If user's profile_picture is still a Google URL, redirect to it
          if user.profile_picture&.include?('googleusercontent.com')
            redirect_to user.profile_picture, status: :moved_permanently
            return
          end
          
          # If we have a cached URL but file doesn't exist, and user is a Google OAuth user,
          # we can't recover the original URL easily, so return a default avatar or 404
          # The user will need to update their profile picture
          Rails.logger.warn "Missing cached profile picture file for user #{user_id}, but no original Google URL available"
        end
        
        # If we can't find the user or original URL, return 404
        render json: { error: 'Profile picture not found' }, status: :not_found
      else
        render json: { error: 'Invalid filename format' }, status: :bad_request
      end
    end
  end
end
