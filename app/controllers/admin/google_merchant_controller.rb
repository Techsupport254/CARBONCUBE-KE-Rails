# app/controllers/admin/google_merchant_controller.rb
class Admin::GoogleMerchantController < ApplicationController
  before_action :authenticate_admin!
  
  # GET /admin/google_merchant/status
  def status
    # Get premium ads only (tier_id = 4)
    premium_ads = Ad.active
                    .joins(seller: { seller_tier: :tier })
                    .where(sellers: { blocked: false, deleted: false, flagged: false })
                    .where(flagged: false)
                    .where.not(media: [nil, [], ""])
                    .where(tiers: { id: 4 })
    
    render json: {
      status: 'Google Merchant API integration is configured',
      last_sync: last_sync_time,
      total_premium_ads: premium_ads.count,
      valid_premium_ads: premium_ads.select { |ad| ad.valid_for_google_merchant? }.count
    }
  end
  
  # POST /admin/google_merchant/sync_all
  def sync_all
    begin
      # Get premium ads only (tier_id = 4)
      premium_ads = Ad.active
                      .joins(seller: { seller_tier: :tier })
                      .where(sellers: { blocked: false, deleted: false, flagged: false })
                      .where(flagged: false)
                      .where.not(media: [nil, [], ""])
                      .where(tiers: { id: 4 })
      
      # Queue background jobs for each ad
      job_count = 0
      premium_ads.find_each do |ad|
        if ad.valid_for_google_merchant?
          GoogleMerchantSyncJob.perform_later(ad.id, 'sync')
          job_count += 1
        end
      end
      
      # Store sync initiation time
      Rails.cache.write('google_merchant_last_sync', Time.current)
      
      render json: {
        success: true,
        message: "Bulk sync initiated for #{job_count} ads",
        total_ads: premium_ads.count,
        queued_jobs: job_count
      }
    rescue => e
      Rails.logger.error "Error initiating bulk sync: #{e.message}"
      render json: {
        success: false,
        error: e.message
      }, status: :internal_server_error
    end
  end
  
  # POST /admin/google_merchant/sync_ad/:id
  def sync_ad
    begin
      ad = Ad.find(params[:id])
      
      if ad.valid_for_google_merchant?
        # Queue background job instead of processing synchronously
        GoogleMerchantSyncJob.perform_later(ad.id, 'sync')
        
        render json: {
          success: true,
          message: "Ad #{ad.id} sync queued for processing"
        }
      else
        render json: {
          success: false,
          error: "Ad #{ad.id} is not valid for Google Merchant sync"
        }, status: :unprocessable_entity
      end
    rescue ActiveRecord::RecordNotFound
      render json: {
        success: false,
        error: "Ad not found"
      }, status: :not_found
    rescue => e
      Rails.logger.error "Error queuing sync for ad #{params[:id]}: #{e.message}"
      render json: {
        success: false,
        error: e.message
      }, status: :internal_server_error
    end
  end
  
  # GET /admin/google_merchant/test_connection
  def test_connection
    begin
      result = GoogleMerchantService.test_connection
      
      if result[:success]
        render json: {
          success: true,
          message: result[:message],
          details: result[:details]
        }
      else
        render json: {
          success: false,
          error: result[:error],
          details: result[:details]
        }, status: :unprocessable_entity
      end
    rescue => e
      Rails.logger.error "Error testing Google Merchant connection: #{e.message}"
      render json: {
        success: false,
        error: "Connection test failed",
        details: e.message
      }, status: :internal_server_error
    end
  end
  
  # POST /admin/google_merchant/cleanup_duplicates
  def cleanup_duplicates
    begin
      Rails.logger.info "Starting duplicate cleanup process..."
      
      result = GoogleMerchantService.cleanup_duplicates
      
      if result[:success]
        render json: {
          success: true,
          message: result[:message],
          deleted_count: result[:deleted_count],
          duplicates_found: result[:duplicates_found],
          total_products: result[:total_products],
          duplicates_by_offer_id: result[:duplicates_by_offer_id],
          duplicates_by_base_id: result[:duplicates_by_base_id],
          products_by_offer_id: result[:products_by_offer_id],
          products_by_base_id: result[:products_by_base_id],
          errors: result[:errors]
        }
      else
        render json: {
          success: false,
          error: result[:error]
        }, status: :unprocessable_entity
      end
    rescue => e
      Rails.logger.error "Error cleaning up duplicates: #{e.message}"
      render json: {
        success: false,
        error: "Cleanup failed",
        details: e.message
      }, status: :internal_server_error
    end
  end
  
  # GET /admin/google_merchant/debug_products
  def debug_products
    begin
      # First check configuration
      config_info = {
        sync_enabled: Rails.application.config.google_merchant_sync[:enabled],
        account_id: Rails.application.config.google_merchant_account_id,
        service_account_key_path: Rails.application.config.google_service_account_key_path,
        key_file_exists: File.exist?(Rails.application.config.google_service_account_key_path || ''),
        env_sync_enabled: ENV['GOOGLE_MERCHANT_SYNC_ENABLED']
      }
      
      result = GoogleMerchantService.list_all_products
      
      if result[:error]
        render json: {
          success: false,
          error: result[:error],
          config: config_info
        }, status: :unprocessable_entity
      else
        # Show first few products for debugging
        sample_products = result[:products].first(5).map do |product|
          creation_time = begin
            product.creation_time
          rescue
            'N/A'
          end
          
          {
            id: product.id,
            offer_id: product.offer_id,
            title: product.title,
            creation_time: creation_time
          }
        end
        
        render json: {
          success: true,
          total_products: result[:total],
          sample_products: sample_products,
          all_offer_ids: result[:products].map(&:offer_id).uniq.first(10),
          config: config_info,
          note: result[:note]
        }
      end
    rescue => e
      Rails.logger.error "Error debugging products: #{e.message}"
      render json: {
        success: false,
        error: "Debug failed",
        details: e.message,
        config: config_info
      }, status: :internal_server_error
    end
  end
  
  # GET /admin/google_merchant/ads
  def ads
    page = params[:page]&.to_i || 1
    per_page = params[:per_page]&.to_i || 50
    per_page = [per_page, 100].min # Cap at 100
    
    # Get premium ads only (tier_id = 4)
    ads = Ad.active
            .joins(seller: { seller_tier: :tier })
            .where(sellers: { blocked: false, deleted: false })
            .where(flagged: false)
            .where.not(media: [nil, [], ""])
            .where(tiers: { id: 4 })
            .includes(:seller, :category, :subcategory, seller: { seller_tier: :tier })
            .order(created_at: :desc)
            .offset((page - 1) * per_page)
            .limit(per_page)
    
    ads_data = ads.map do |ad|
      {
        id: ad.id,
        title: ad.title,
        description: ad.description,
        price: ad.price,
        brand: ad.brand,
        manufacturer: ad.manufacturer,
        condition: ad.condition,
        media: ad.media,
        first_image: ad.first_valid_media_url,
        seller: {
          id: ad.seller.id,
          enterprise_name: ad.seller.enterprise_name,
          tier_name: ad.seller.seller_tier&.tier&.name
        },
        category: ad.category&.name,
        subcategory: ad.subcategory&.name,
        valid_for_google_merchant: ad.valid_for_google_merchant?,
        validation_errors: ad.google_merchant_validation_errors,
        product_url: ad.product_url,
        google_merchant_data: ad.google_merchant_data,
        created_at: ad.created_at,
        updated_at: ad.updated_at
      }
    end
    
    # Count total premium ads
    total_premium_ads = Ad.active
                          .joins(seller: { seller_tier: :tier })
                          .where(sellers: { blocked: false, deleted: false, flagged: false })
                          .where(flagged: false)
                          .where.not(media: [nil, [], ""])
                          .where(tiers: { id: 4 })
                          .count
    
    render json: {
      ads: ads_data,
      pagination: {
        page: page,
        per_page: per_page,
        total: total_premium_ads,
        total_pages: (total_premium_ads.to_f / per_page).ceil
      }
    }
  end
  
  private
  
  def last_sync_time
    # This would typically be stored in a cache or database
    # For now, return a placeholder
    Rails.cache.read('google_merchant_last_sync') || 'Never'
  end
  
  def authenticate_admin!
    # Add your admin authentication logic here
    # This is a placeholder - implement based on your admin authentication
    true
  end
end
