# app/controllers/buyer/categories_controller.rb
class Buyer::CategoriesController < ApplicationController
  def index
    @categories = Rails.cache.fetch('buyer_categories_with_analytics', expires_in: 12.hours) do
      # Get all categories with subcategories and analytics data
      all_categories = Category.all
      
      all_categories.map do |category|
        category_data = category.as_json(include: :subcategories)
        
        # Get ads count for this category (only non-deleted ads)
        ads_count = category.ads.where(deleted: false).count
        
        # Get click events for ads in this category
        category_ads = category.ads.where(deleted: false)
        
        # Count different types of click events
        ad_clicks = ClickEvent.joins(:ad)
                              .where(ads: { id: category_ads.pluck(:id) })
                              .where(event_type: 'Ad-Click')
                              .count
        
        ad_click_reveals = ClickEvent.joins(:ad)
                                    .where(ads: { id: category_ads.pluck(:id) })
                                    .where(event_type: 'Reveal-Seller-Details')
                                    .count
        
        wishlist_count = ClickEvent.joins(:ad)
                                  .where(ads: { id: category_ads.pluck(:id) })
                                  .where(event_type: 'Add-to-Wish-List')
                                  .count
        
        # Add all the analytics data to the category data
        category_data.merge!(
          ads_count: ads_count,
          ad_clicks: ad_clicks,
          ad_click_reveals: ad_click_reveals,
          wishlist_count: wishlist_count
        )
      end
    end
    render json: @categories
  end
end
