# app/services/google_merchant_service.rb
class GoogleMerchantService
  # Google Merchant Center API service
  def self.content_service
    @content_service ||= Google::Apis::ContentV2_1::ShoppingContentService.new
  end
  
    # Sync a single ad to Google Merchant Center
  def self.sync_ad(ad)
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
  def self.sync_all_active_ads
      Rails.logger.info "Starting bulk sync of all premium ads to Google Merchant Center"
      
      ads = Ad.active
               .joins(seller: { seller_tier: :tier })
               .includes(:seller)
               .where(sellers: { blocked: false, deleted: false, flagged: false })
               .where(flagged: false)
               .where(tiers: { id: 4 }) # Premium tier
      
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
    
  # Test connection to Google Merchant API by syncing Pantech Kenya Limited ads
  def self.test_connection
    Rails.logger.info "Testing Google Merchant API connection by syncing Pantech Kenya Limited ads..."
    
    # Check if sync is enabled - if not, do a mock test
    unless Rails.application.config.google_merchant_sync[:enabled]
      Rails.logger.info "Google Merchant sync is disabled, performing mock test..."
      
      # Find any premium seller for mock testing
      test_seller = Seller.joins(:seller_tier, :tier)
                         .where(deleted: false, blocked: false)
                         .where(tiers: { id: 4 }) # Premium tier
                         .first
      
      unless test_seller
        return {
          success: false,
          error: "No premium sellers found for testing",
          details: "No active premium sellers available"
        }
      end
      
      # Get a few ads for mock testing
      test_ads = test_seller.ads.active.limit(3)
      
      return {
        success: true,
        message: "Mock test successful - Google Merchant sync is disabled",
        details: {
          seller: test_seller.enterprise_name,
          ads_tested: test_ads.count,
          note: "Enable GOOGLE_MERCHANT_SYNC_ENABLED for real API testing"
        }
      }
    end
    
    # Real API test
    begin
      # Check environment variables
      unless Rails.application.config.google_merchant_account_id.present?
        return {
          success: false,
          error: "Google Merchant Account ID not configured",
          details: "Set GOOGLE_MERCHANT_ACCOUNT_ID environment variable"
        }
      end
      
      # Check service account key
      key_path = Rails.application.config.google_service_account_key_path
      unless key_path.present? && File.exist?(key_path)
        return {
          success: false,
          error: "Service account key not found",
          details: "Set GOOGLE_SERVICE_ACCOUNT_KEY_PATH and ensure file exists"
        }
      end
      
      # Test API connection
      account_id = Rails.application.config.google_merchant_account_id
      content_service.authorization = get_authorization
      
      # Test account access
      begin
        account = content_service.get_account(account_id, account_id)
        Rails.logger.info "Successfully connected to Google Merchant Center account: #{account.name}"
      rescue Google::Apis::ClientError => e
        if e.message.include?("Unauthorized")
          return {
            success: false,
            error: "Unauthorized access to Google Merchant Center",
            details: "Service account needs to be added to Google Merchant Center with Admin or Content Manager role"
          }
        else
          raise e
        end
      end
      
      # Find Pantech Kenya Limited or any premium seller
      pantech_seller = Seller.joins(:seller_tier, :tier)
                            .where(deleted: false, blocked: false)
                            .where(tiers: { id: 4 }) # Premium tier
                            .where("LOWER(enterprise_name) LIKE ?", "%pantech%")
                            .first
      
      unless pantech_seller
        # Fallback to any premium seller
        pantech_seller = Seller.joins(:seller_tier, :tier)
                              .where(deleted: false, blocked: false)
                              .where(tiers: { id: 4 }) # Premium tier
                              .first
      end
      
      unless pantech_seller
        return {
          success: false,
          error: "No premium sellers found",
          details: "No active premium sellers available for testing"
        }
      end
      
      # Get Pantech ads (or any premium ads)
      pantech_ads = pantech_seller.ads.active.limit(3)
      
      if pantech_ads.empty?
        return {
          success: false,
          error: "No active ads found for testing",
          details: "No active ads found for seller: #{pantech_seller.enterprise_name}"
        }
      end
      
      # Test sync with Pantech ads
      test_results = []
      pantech_ads.each do |ad|
        # Validate ad first
        validation = validate_ad_for_google_merchant(ad)
        
        if validation[:valid]
          begin
            product_data = build_product_data(ad)
            response = send_to_merchant_api(product_data, ad)
            
            test_results << {
              ad_id: ad.id,
              title: ad.title,
              success: response.success?,
              message: response.success? ? "Sync successful" : "Sync failed: #{response.body}",
              validation: validation
            }
          rescue => e
            test_results << {
              ad_id: ad.id,
              title: ad.title,
              success: false,
              message: "Error: #{e.message}",
              validation: validation
            }
          end
        else
          test_results << {
            ad_id: ad.id,
            title: ad.title,
            success: false,
            message: "Validation failed: #{validation[:errors].join(', ')}",
            validation: validation
          }
        end
      end
      
      success_count = test_results.count { |r| r[:success] }
      total_count = test_results.count
      
      {
        success: success_count > 0,
        message: "Test completed: #{success_count}/#{total_count} ads synced successfully",
        details: {
          seller: pantech_seller.enterprise_name,
          test_results: test_results,
          summary: "#{success_count} successful, #{total_count - success_count} failed"
        }
      }
      
    rescue Google::Apis::ClientError => e
      Rails.logger.error "Google API Client Error: #{e.message}"
      {
        success: false,
        error: "Google API Client Error",
        details: e.message
      }
    rescue Google::Apis::ServerError => e
      Rails.logger.error "Google API Server Error: #{e.message}"
      {
        success: false,
        error: "Google API Server Error",
        details: e.message
      }
    rescue => e
      Rails.logger.error "Unexpected error during test sync: #{e.message}"
      {
        success: false,
        error: "Test sync failed",
        details: e.message
      }
    end
  end
  
  # Validate ad for Google Merchant with detailed error messages
  def self.validate_ad_for_google_merchant(ad)
    errors = []
    
    # Basic ad validation
    unless ad
      errors << "Ad not found"
      return { valid: false, errors: errors }
    end
    
    if ad.deleted?
      errors << "Ad is deleted"
    end
    
    if ad.flagged?
      errors << "Ad is flagged"
    end
    
    # Seller validation
    unless ad.seller
      errors << "No seller associated"
    else
      if ad.seller.blocked?
        errors << "Seller is blocked"
      end
      if ad.seller.deleted?
        errors << "Seller is deleted"
      end
    end
    
    # Content validation
    if ad.title.blank?
      errors << "Title is required"
    elsif ad.title.length < 10
      errors << "Title too short (minimum 10 characters)"
    elsif ad.title.length > 150
      errors << "Title too long (maximum 150 characters)"
    end
    
    if ad.description.blank?
      errors << "Description is required"
    elsif ad.description.length < 20
      errors << "Description too short (minimum 20 characters)"
    elsif ad.description.length > 5000
      errors << "Description too long (maximum 5000 characters)"
    end
    
    # Price validation
    if ad.price.blank?
      errors << "Price is required"
    elsif ad.price <= 0
      errors << "Price must be greater than 0"
    elsif ad.price > 1000000
      errors << "Price too high (maximum 1,000,000 KES)"
    end
    
    # Image validation
    unless ad.has_valid_images?
      errors << "Valid product images are required"
    end
    
    # Brand validation (optional but recommended)
    if ad.brand.blank?
      errors << "Brand is recommended for better visibility"
    end
    
    # Category validation
    if ad.category.blank?
      errors << "Category is required"
    end
    
    # Condition validation
    unless ad.condition.present?
      errors << "Product condition is required"
    end
    
    {
      valid: errors.empty?,
      errors: errors,
      warnings: errors.select { |e| e.include?("recommended") }
    }
    end
    
    private
    
    # Check if ad is valid for Google Merchant sync
  def self.ad_valid_for_sync?(ad)
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
  def self.build_product_data(ad)
    {
      offerId: "carbon_cube_#{ad.id}",
      contentLanguage: "en",
      feedLabel: "carbon_cube_feed",
        productAttributes: {
          title: ad.title,
          description: ad.description,
        link: "https://carboncube-ke.com/ads/#{ad.id}",
          imageLink: ad.first_valid_media_url,
        availability: "in stock",
          price: {
          value: ad.price.to_f,
          currency: "KES"
        },
        condition: normalize_condition(ad.condition),
        brand: normalize_brand(ad.brand, ad.title)
      }
    }
    end
    
  # Create URL-friendly slug from title
  def self.create_slug(title)
    return nil if title.blank?
    
    title.downcase
         .gsub(/[^a-z0-9\s-]/, '')
         .gsub(/\s+/, '-')
         .gsub(/-+/, '-')
         .gsub(/^-|-$/, '')
  end
  
  # Normalize condition for Google Merchant
  def self.normalize_condition(condition)
    return "new" if condition.blank?
    
    case condition.downcase
    when "brand_new", "new", "unused", "x_japan", "x-japan"
      "new"
    when "used", "second_hand", "pre_owned"
      "used"
    when "refurbished", "reconditioned"
      "refurbished"
    else
      "new"
    end
  end
  
  # Normalize brand for Google Merchant
  def self.normalize_brand(brand, title)
    return "Unknown" if brand.blank?
    
    # If brand is the same as title, try to extract brand from title
    if brand == title
      # Try to extract brand from common patterns
      if title.match?(/^(Samsung|Apple|Nokia|LG|Sony|HP|Dell|Lenovo|Asus|Acer|Toshiba|Canon|Nikon|Sony|Panasonic|Philips|Bosch|Whirlpool|LG|Samsung|Apple|iPhone|iPad|MacBook|Galaxy|Pixel)/i)
        title.split.first
      else
        "Generic"
      end
    else
      brand
    end
  end
    
    # Send data to Google Merchant API with upsert logic
  def self.send_to_merchant_api(product_data, ad)
      return mock_response if Rails.env.development? && !Rails.application.config.google_merchant_sync[:enabled]
      
      account_id = Rails.application.config.google_merchant_account_id
      return mock_response unless account_id.present?
      
      begin
        # Set up authentication
        content_service.authorization = get_authorization
        
      # Create product object
      product = Google::Apis::ContentV2_1::Product.new(
          offer_id: product_data[:offerId],
          content_language: product_data[:contentLanguage],
          feed_label: product_data[:feedLabel],
        channel: "online",
        title: product_data[:productAttributes][:title],
        description: product_data[:productAttributes][:description],
        link: product_data[:productAttributes][:link],
        image_link: product_data[:productAttributes][:imageLink],
        availability: product_data[:productAttributes][:availability],
        price: build_price(product_data[:productAttributes][:price]),
        condition: product_data[:productAttributes][:condition],
        brand: product_data[:productAttributes][:brand]
        )
        
        # Check if product already exists
        existing_product_id = ad.google_merchant_product_id
        existing_product = nil
        
        if existing_product_id.present?
          # We have a stored Google Merchant product ID, try to update
          begin
            existing_product = content_service.get_product(account_id, existing_product_id)
            Rails.logger.info "Found existing product by stored ID: #{existing_product_id}"
          rescue Google::Apis::ClientError => e
            if e.message.include?("not found") || e.message.include?("404")
              # Product was deleted from Google Merchant, clear our stored ID
              ad.update_column(:google_merchant_product_id, nil)
              Rails.logger.info "Stored product ID #{existing_product_id} no longer exists, will create new product"
            else
              raise e
            end
          rescue => e
            Rails.logger.error "Error checking existing product: #{e.message}"
          end
        end
        
        if existing_product
          # Update existing product
          result = content_service.update_product(
              account_id,
              existing_product.id,
              product
          )
          Rails.logger.info "Product updated successfully: #{result.id}"
        else
          # Insert new product
          result = content_service.insert_product(
              account_id,
              product
          )
          Rails.logger.info "Product inserted successfully: #{result.id}"
        end
        
        # Store the Google Merchant product ID in the ad record
        store_google_merchant_id(ad, result.id)
        
        OpenStruct.new(success?: true, body: result.to_json)
        
    rescue Google::Apis::ClientError => e
      Rails.logger.error "Google API Client Error: #{e.message}"
      OpenStruct.new(success?: false, body: e.message)
    rescue Google::Apis::ServerError => e
      Rails.logger.error "Google API Server Error: #{e.message}"
      OpenStruct.new(success?: false, body: e.message)
      rescue => e
      Rails.logger.error "Unexpected error: #{e.message}"
        OpenStruct.new(success?: false, body: e.message)
      end
    end
    
  def self.mock_response
      OpenStruct.new(success?: true, body: 'Mock successful response')
    end
    
    # Get Google API authorization
  def self.get_authorization
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
    
    # Build price object for Google API
  def self.build_price(price_data)
      return nil unless price_data
      
      Google::Apis::ContentV2_1::Price.new(
      value: price_data[:value],
      currency: price_data[:currency]
      )
  end
  
  
  # Store Google Merchant product ID in ad record
  def self.store_google_merchant_id(ad, google_product_id)
    begin
      # Update the ad with Google Merchant product ID
      ad.update_column(:google_merchant_product_id, google_product_id)
      Rails.logger.info "Stored Google Merchant product ID #{google_product_id} for ad #{ad.id}"
    rescue => e
      Rails.logger.error "Error storing Google Merchant product ID: #{e.message}"
    end
  end
  
  # Delete product from Google Merchant Center
  def self.delete_product(ad)
    return false unless ad.google_merchant_product_id.present?
    
    return mock_response if Rails.env.development? && !Rails.application.config.google_merchant_sync[:enabled]
    
    account_id = Rails.application.config.google_merchant_account_id
    return mock_response unless account_id.present?
    
    begin
      content_service.authorization = get_authorization
      
      # Delete the product
      content_service.delete_product(account_id, ad.google_merchant_product_id)
      
      # Clear the stored product ID
      ad.update_column(:google_merchant_product_id, nil)
      
      Rails.logger.info "Successfully deleted product #{ad.google_merchant_product_id} from Google Merchant Center for ad #{ad.id}"
      true
    rescue Google::Apis::ClientError => e
      if e.message.include?("not found") || e.message.include?("404")
        # Product already deleted, just clear our stored ID
        ad.update_column(:google_merchant_product_id, nil)
        Rails.logger.info "Product #{ad.google_merchant_product_id} was already deleted from Google Merchant Center"
        true
      else
        Rails.logger.error "Google API Client Error deleting product: #{e.message}"
        false
      end
    rescue => e
      Rails.logger.error "Error deleting product from Google Merchant Center: #{e.message}"
      false
    end
  end
  
  # List all products from Google Merchant Center
  def self.list_all_products
    Rails.logger.info "Starting to list products from Google Merchant Center..."
    
    # Check if sync is enabled
    unless Rails.application.config.google_merchant_sync[:enabled]
      Rails.logger.info "Google Merchant sync is disabled, returning empty result"
      return { products: [], total: 0, note: "Google Merchant sync is disabled" }
    end
    
    account_id = Rails.application.config.google_merchant_account_id
    Rails.logger.info "Using account ID: #{account_id}"
    
    unless account_id.present?
      Rails.logger.error "Google Merchant Account ID not configured"
      return { products: [], total: 0, error: "Google Merchant Account ID not configured" }
    end
    
    begin
      Rails.logger.info "Setting up authorization..."
      content_service.authorization = get_authorization
      
      if content_service.authorization.nil?
        Rails.logger.error "Failed to get authorization"
        return { products: [], total: 0, error: "Failed to get authorization" }
      end
      
      Rails.logger.info "Authorization successful, listing products..."
      
      # Get all products with pagination
      all_products = []
      page_token = nil
      page_count = 0
      
      loop do
        page_count += 1
        Rails.logger.info "Fetching page #{page_count}..."
        
        response = content_service.list_products(
          account_id,
          max_results: 250, # Maximum allowed
          page_token: page_token
        )
        
        Rails.logger.info "Page #{page_count} returned #{response.resources&.count || 0} products"
        
        all_products.concat(response.resources || [])
        
        break unless response.next_page_token
        page_token = response.next_page_token
        
        # Add delay to avoid rate limiting
        sleep(0.1)
      end
      
      Rails.logger.info "Retrieved #{all_products.count} products from Google Merchant Center in #{page_count} pages"
      { products: all_products, total: all_products.count }
      
    rescue Google::Apis::ClientError => e
      Rails.logger.error "Google API Client Error listing products: #{e.message}"
      { products: [], total: 0, error: "Google API Client Error: #{e.message}" }
    rescue Google::Apis::ServerError => e
      Rails.logger.error "Google API Server Error listing products: #{e.message}"
      { products: [], total: 0, error: "Google API Server Error: #{e.message}" }
    rescue => e
      Rails.logger.error "Error listing products from Google Merchant Center: #{e.message}"
      Rails.logger.error "Error class: #{e.class}"
      Rails.logger.error "Error backtrace: #{e.backtrace.first(5).join('\n')}"
      { products: [], total: 0, error: e.message }
    end
  end
  
  # Clean up duplicate products in Google Merchant Center
  def self.cleanup_duplicates
    Rails.logger.info "Starting cleanup of duplicate products in Google Merchant Center..."
    
    # Get all products from Google Merchant
    result = list_all_products
    return { success: false, error: "Failed to list products: #{result[:error]}" } if result[:error]
    
    products = result[:products]
    Rails.logger.info "Found #{products.count} total products in Google Merchant Center"
    
    # Debug: Log some product details
    if products.any?
      Rails.logger.info "Sample products:"
      products.first(3).each_with_index do |product, index|
        Rails.logger.info "Product #{index + 1}: ID=#{product.id}, OfferID=#{product.offer_id}, Title=#{product.title}"
      end
    end
    
    return { success: true, message: "No products found in Google Merchant Center" } if products.empty?
    
    # Group products by offer_id to find duplicates
    products_by_offer_id = products.group_by(&:offer_id)
    Rails.logger.info "Products grouped by offer_id: #{products_by_offer_id.keys.first(5)}"
    
    # Also group by base ID (without carbon_cube_ prefix) to find duplicates
    products_by_base_id = {}
    products.each do |product|
      base_id = product.offer_id.gsub(/^carbon_cube_/, '')
      products_by_base_id[base_id] ||= []
      products_by_base_id[base_id] << product
    end
    
    Rails.logger.info "Products grouped by base ID: #{products_by_base_id.keys.first(5)}"
    
    # Find duplicates by both offer_id and base_id
    duplicates_by_offer_id = products_by_offer_id.select { |offer_id, products| products.count > 1 }
    duplicates_by_base_id = products_by_base_id.select { |base_id, products| products.count > 1 }
    
    Rails.logger.info "Found #{duplicates_by_offer_id.count} offer_ids with duplicates"
    Rails.logger.info "Found #{duplicates_by_base_id.count} base IDs with duplicates"
    
    # Combine both types of duplicates
    all_duplicates = {}
    
    # Add duplicates by offer_id
    duplicates_by_offer_id.each do |offer_id, duplicate_products|
      all_duplicates[offer_id] = duplicate_products
    end
    
    # Add duplicates by base_id (these are the main ones we want to catch)
    duplicates_by_base_id.each do |base_id, duplicate_products|
      # Use the first offer_id as the key for this group
      key = duplicate_products.first.offer_id
      all_duplicates[key] = duplicate_products
    end
    
    duplicates = all_duplicates
    Rails.logger.info "Total duplicate groups found: #{duplicates.count}"
    
    # If no duplicates found, return detailed info
    if duplicates.empty?
      return {
        success: true,
        message: "No duplicates found. Total products: #{products.count}",
        total_products: products.count,
        duplicates_found: 0,
        deleted_count: 0,
        products_by_offer_id: products_by_offer_id.transform_values(&:count),
        products_by_base_id: products_by_base_id.transform_values(&:count),
        duplicates_by_offer_id: duplicates_by_offer_id.count,
        duplicates_by_base_id: duplicates_by_base_id.count
      }
    end
    
    deleted_count = 0
    errors = []
    
    duplicates.each do |offer_id, duplicate_products|
      Rails.logger.info "Processing duplicates for offer_id: #{offer_id} (#{duplicate_products.count} products)"
      
      # Sort by creation time (keep the newest, delete older ones)
      sorted_products = duplicate_products.sort_by do |p|
        begin
          p.creation_time
        rescue
          Time.at(0)
        end
      end
      products_to_delete = sorted_products[0..-2] # All except the last (newest)
      product_to_keep = sorted_products.last
      
      Rails.logger.info "Keeping product #{product_to_keep.id}, deleting #{products_to_delete.count} duplicates"
      
      # Delete the older duplicates
      products_to_delete.each do |product|
        begin
          content_service.delete_product(
            Rails.application.config.google_merchant_account_id,
            product.id
          )
          deleted_count += 1
          Rails.logger.info "Deleted duplicate product: #{product.id}"
        rescue => e
          error_msg = "Failed to delete product #{product.id}: #{e.message}"
          Rails.logger.error error_msg
          errors << error_msg
        end
      end
      
      # Update our database with the kept product ID
      begin
        # Extract ad ID from offer_id (format: carbon_cube_123)
        ad_id = offer_id.gsub('carbon_cube_', '').to_i
        ad = Ad.find(ad_id)
        ad.update_column(:google_merchant_product_id, product_to_keep.id)
        Rails.logger.info "Updated ad #{ad_id} with Google Merchant product ID: #{product_to_keep.id}"
      rescue => e
        Rails.logger.error "Failed to update ad #{ad_id}: #{e.message}"
        errors << "Failed to update ad #{ad_id}: #{e.message}"
      end
    end
    
    {
      success: true,
      message: "Cleanup completed: deleted #{deleted_count} duplicate products",
      deleted_count: deleted_count,
      duplicates_found: duplicates.count,
      total_products: products.count,
      duplicates_by_offer_id: duplicates_by_offer_id.count,
      duplicates_by_base_id: duplicates_by_base_id.count,
      products_by_offer_id: products_by_offer_id.transform_values(&:count),
      products_by_base_id: products_by_base_id.transform_values(&:count),
      errors: errors
    }
  end
end