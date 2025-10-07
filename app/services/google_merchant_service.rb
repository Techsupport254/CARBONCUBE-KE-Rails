# app/services/google_merchant_service.rb
require 'google/apis/content_v2_1'
require 'googleauth'

class GoogleMerchantService
  # Google Merchant Center API service
  def self.content_service
    @content_service ||= Google::Apis::ContentV2_1::ShoppingContentService.new
  end
  
  class << self
    # Sync a single ad to Google Merchant Center
    def sync_ad(ad)
      return false unless ad_valid_for_sync?(ad)
      
      begin
        product_data = build_product_data(ad)
        response = send_to_merchant_api(product_data, ad)
        
        if response.success?
          Rails.logger.info "Successfully synced ad #{ad.id} to Google Merchant Center"
          true
        else
          Rails.logger.error "Failed to sync ad #{ad.id}: #{response.body}"
          false
        end
      rescue => e
        Rails.logger.error "Error syncing ad #{ad.id}: #{e.message}"
        false
      end
    end
    
    # Sync all premium ads to Google Merchant Center
    def sync_all_active_ads
      Rails.logger.info "Starting bulk sync of all premium ads to Google Merchant Center"
      
      ads = Ad.active
               .joins(seller: { seller_tier: :tier })
               .includes(:seller)
               .where(sellers: { blocked: false, deleted: false })
               .where(flagged: false)
               .where.not(media: [nil, [], ""])
               .where(tiers: { id: 4 }) # Premium tier only
      
      success_count = 0
      failure_count = 0
      
      ads.find_each do |ad|
        if sync_ad(ad)
          success_count += 1
        else
          failure_count += 1
        end
        
        # Add small delay to avoid rate limiting
        sleep(0.1)
      end
      
      Rails.logger.info "Bulk sync completed: #{success_count} successful, #{failure_count} failed"
      { success: success_count, failed: failure_count }
    end
    
    # Test connection to Google Merchant API
    def test_connection
      # This would test the API connection
      # Implementation depends on your authentication setup
      Rails.logger.info "Testing Google Merchant API connection..."
      # Add your connection test logic here
    end
    
    private
    
    # Check if ad is valid for Google Merchant sync
    def ad_valid_for_sync?(ad)
      return false unless ad
      return false if ad.deleted?
      return false if ad.flagged?
      return false unless ad.seller
      return false if ad.seller.blocked?
      return false if ad.seller.deleted?
      return false unless ad.has_valid_images?
      return false if ad.title.blank?
      return false if ad.description.blank?
      return false if ad.price.blank? || ad.price <= 0
      
      true
    end
    
    # Build product data for Google Merchant API
    def build_product_data(ad)
      {
        offerId: ad.id.to_s,
        contentLanguage: 'en',
        feedLabel: 'primary',
        productAttributes: {
          title: ad.title,
          description: ad.description,
          link: generate_product_url(ad),
          imageLink: ad.first_valid_media_url,
          availability: 'IN_STOCK',
          price: {
            amountMicros: (ad.price * 1000000).to_i.to_s,
            currencyCode: 'KES'
          },
          condition: map_condition(ad.condition),
          brand: ad.brand.present? ? ad.brand : nil
        }.compact
      }
    end
    
    # Generate product URL using your existing URL structure
    def generate_product_url(ad)
      slug = create_slug(ad.title)
      "https://carboncube-ke.com/ads/#{slug}?id=#{ad.id}"
    end
    
    # Create URL-friendly slug from title
    def create_slug(title)
      return "product-#{Time.current.to_i}" if title.blank?
      
      title.downcase
           .gsub(/[^a-z0-9\s]/, '')
           .gsub(/\s+/, '-')
           .strip
    end
    
    # Map your condition enum to Google's condition values
    def map_condition(condition)
      case condition
      when 'brand_new' then 'NEW'
      when 'second_hand' then 'USED'
      when 'refurbished' then 'REFURBISHED'
      else 'NEW'
      end
    end
    
    # Send data to Google Merchant API
    def send_to_merchant_api(product_data, ad)
      return mock_response if Rails.env.development? && !Rails.application.config.google_merchant_sync[:enabled]
      
      account_id = Rails.application.config.google_merchant_account_id
      return mock_response unless account_id.present?
      
      begin
        # Set up authentication
        content_service.authorization = get_authorization
        
        # Create product input object
        product_input = Google::Apis::ContentV2_1::ProductInput.new(
          offer_id: product_data[:offerId],
          content_language: product_data[:contentLanguage],
          feed_label: product_data[:feedLabel],
          product_attributes: build_product_attributes(product_data[:productAttributes])
        )
        
        # Insert product
        result = content_service.insert_product_input(
          account_id,
          product_input
        )
        
        Rails.logger.info "Google Merchant API Success for Ad #{ad.id}: #{result.inspect}"
        OpenStruct.new(success?: true, body: result.to_json)
        
      rescue => e
        Rails.logger.error "Google Merchant API Exception for Ad #{ad.id}: #{e.message}"
        OpenStruct.new(success?: false, body: e.message)
      end
    end
    
    def mock_response
      OpenStruct.new(success?: true, body: 'Mock successful response')
    end
    
    # Get Google API authorization
    def get_authorization
      return nil unless Rails.application.config.google_merchant_sync[:enabled]
      
      key_path = Rails.application.config.google_service_account_key_path
      return nil unless key_path.present? && File.exist?(key_path)
      
      # Load service account credentials
      credentials = Google::Auth::ServiceAccountCredentials.make_creds(
        json_key_io: File.open(key_path),
        scope: 'https://www.googleapis.com/auth/content'
      )
      
      credentials
    end
    
    # Build product attributes for Google API
    def build_product_attributes(attrs)
      Google::Apis::ContentV2_1::ProductAttributes.new(
        title: attrs[:title],
        description: attrs[:description],
        link: attrs[:link],
        image_link: attrs[:imageLink],
        availability: attrs[:availability],
        price: build_price(attrs[:price]),
        condition: attrs[:condition],
        brand: attrs[:brand]
      )
    end
    
    # Build price object for Google API
    def build_price(price_data)
      return nil unless price_data
      
      Google::Apis::ContentV2_1::Price.new(
        amount_micros: price_data[:amountMicros],
        currency_code: price_data[:currencyCode]
      )
    end
  end
end
