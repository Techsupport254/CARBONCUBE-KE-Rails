class ProfilePicturesController < ApplicationController
  # Serve cached profile pictures
  def show
    filename = params[:filename]
    
    # Security: Only allow jpg files and prevent directory traversal
    unless filename.match?(/\Auser_\d+_\d+\.jpg\z/)
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
      user_id = filename.match(/\Auser_(\d+)_\d+\.jpg\z/)[1]
      user = Buyer.find_by(id: user_id) || Seller.find_by(id: user_id)
      if user&.profile_picture&.include?('googleusercontent.com')
        redirect_to user.profile_picture, status: :moved_permanently
      else
        render json: { error: 'Profile picture not found' }, status: :not_found
      end
    end
  end
end
