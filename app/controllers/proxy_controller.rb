class ProxyController < ApplicationController
  # Proxy endpoint for external images (like Google profile pictures)
  def proxy_image
    image_url = params[:url]
    
    if image_url.blank?
      render json: { error: 'URL parameter is required' }, status: :bad_request
      return
    end
    
    # Validate that it's a Google profile image URL for security
    unless image_url.include?('googleusercontent.com') || image_url.include?('googleapis.com')
      render json: { error: 'Only Google profile images are allowed' }, status: :forbidden
      return
    end
    
    begin
      # Fetch the image from Google's servers
      response = HTTParty.get(image_url, timeout: 10)
      
      if response.success?
        # Set appropriate headers
        headers['Content-Type'] = response.headers['content-type'] || 'image/jpeg'
        headers['Cache-Control'] = 'public, max-age=3600' # Cache for 1 hour
        
        # Return the image data
        render body: response.body
      else
        render json: { error: 'Failed to fetch image' }, status: :bad_gateway
      end
    rescue => e
      Rails.logger.error "Proxy image error: #{e.message}"
      render json: { error: 'Failed to proxy image' }, status: :internal_server_error
    end
  end
end
