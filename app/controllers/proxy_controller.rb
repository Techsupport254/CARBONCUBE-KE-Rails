class ProxyController < ApplicationController
  CACHE_TTL = 24.hours

  # Proxy endpoint for external images (like Google profile pictures)
  # Caches the fetched bytes in Redis so we don't hit Google on every
  # dashboard/shop page load - this avoids broken images from Google's
  # hotlink/rate limiting when many requests come from our servers/browsers.
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

    cache_key = "image_proxy:#{Digest::MD5.hexdigest(image_url)}"
    cached = Rails.cache.read(cache_key)

    if cached.present?
      headers['Content-Type'] = cached[:content_type]
      headers['Cache-Control'] = "public, max-age=#{CACHE_TTL.to_i}"
      headers['X-Image-Cache'] = 'HIT'
      render body: cached[:body]
      return
    end

    begin
      # Fetch the image from Google's servers
      response = HTTParty.get(image_url, timeout: 10)

      if response.success?
        content_type = response.headers['content-type'] || 'image/jpeg'

        Rails.cache.write(
          cache_key,
          { content_type: content_type, body: response.body },
          expires_in: CACHE_TTL
        )

        headers['Content-Type'] = content_type
        headers['Cache-Control'] = "public, max-age=#{CACHE_TTL.to_i}"
        headers['X-Image-Cache'] = 'MISS'
        render body: response.body
      else
        Rails.logger.warn "Proxy image fetch failed: #{response.code} for #{image_url}"
        render json: { error: 'Failed to fetch image' }, status: :bad_gateway
      end
    rescue => e
      Rails.logger.error "Proxy image error: #{e.message}"
      render json: { error: 'Failed to proxy image' }, status: :internal_server_error
    end
  end
end
