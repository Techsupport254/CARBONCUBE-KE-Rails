# app/controllers/buyer/categories_controller.rb
class Buyer::CategoriesController < ApplicationController
  def index
    @categories = Rails.cache.fetch('buyer_categories_with_analytics', expires_in: 12.hours) do
      # Get all categories with subcategories
      all_categories = Category.includes(:subcategories).all
      
      # Pre-fetch all analytics data in bulk to avoid N+1 queries
      category_ids = all_categories.map(&:id)
      
      # Get ads counts for all categories in one query
      ads_counts = Ad.where(category_id: category_ids, deleted: false)
                     .group(:category_id)
                     .count
      
      # Get all ad IDs for categories
      category_ad_ids = Ad.where(category_id: category_ids, deleted: false).pluck(:id)
      
      # Get click events for all categories in one query per event type
      ad_clicks = ClickEvent.joins(:ad)
                           .where(ads: { id: category_ad_ids })
                           .where(event_type: 'Ad-Click')
                           .group('ads.category_id')
                           .count
      
      ad_click_reveals = ClickEvent.joins(:ad)
                                  .where(ads: { id: category_ad_ids })
                                  .where(event_type: 'Reveal-Seller-Details')
                                  .group('ads.category_id')
                                  .count
      
      wishlist_counts = ClickEvent.joins(:ad)
                                 .where(ads: { id: category_ad_ids })
                                 .where(event_type: 'Add-to-Wish-List')
                                 .group('ads.category_id')
                                 .count
      
      all_categories.map do |category|
        category_data = category.as_json(include: :subcategories)
        
        # Add all the analytics data to the category data
        category_data.merge!(
          ads_count: ads_counts[category.id] || 0,
          ad_clicks: ad_clicks[category.id] || 0,
          ad_click_reveals: ad_click_reveals[category.id] || 0,
          wishlist_count: wishlist_counts[category.id] || 0
        )
      end
    end
    render json: @categories
  end
end
