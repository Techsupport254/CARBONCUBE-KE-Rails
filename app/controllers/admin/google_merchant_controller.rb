# app/controllers/admin/google_merchant_controller.rb
class Admin::GoogleMerchantController < ApplicationController
  before_action :authenticate_admin!
  
  # GET /admin/google_merchant/status
  def status
    # Get premium ads only (tier_id = 4)
    premium_ads = Ad.active
                    .joins(seller: { seller_tier: :tier })
                    .where(sellers: { blocked: false, deleted: false })
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
      result = GoogleMerchantService.sync_all_active_ads
      
      render json: {
        success: true,
        message: "Bulk sync initiated",
        result: result
      }
    rescue => e
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
        success = GoogleMerchantService.sync_ad(ad)
        
        if success
          render json: {
            success: true,
            message: "Ad #{ad.id} synced successfully"
          }
        else
          render json: {
            success: false,
            error: "Failed to sync ad #{ad.id}"
          }, status: :unprocessable_entity
        end
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
      render json: {
        success: false,
        error: e.message
      }, status: :internal_server_error
    end
  end
  
  # GET /admin/google_merchant/test_connection
  def test_connection
    begin
      GoogleMerchantService.test_connection
      
      render json: {
        success: true,
        message: "Connection test completed"
      }
    rescue => e
      render json: {
        success: false,
        error: e.message
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
        product_url: ad.product_url,
        google_merchant_data: ad.google_merchant_data,
        created_at: ad.created_at,
        updated_at: ad.updated_at
      }
    end
    
    # Count total premium ads
    total_premium_ads = Ad.active
                          .joins(seller: { seller_tier: :tier })
                          .where(sellers: { blocked: false, deleted: false })
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
