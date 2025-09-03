# app/controllers/buyer/categories_controller.rb
class Buyer::CategoriesController < ApplicationController
  def index
    @categories = Rails.cache.fetch('buyer_categories_with_ads_count', expires_in: 24.hours) do
      # Get categories with subcategories and ads count
      Category.includes(:subcategories, :ads).all.map do |category|
        category_data = category.as_json(include: :subcategories)
        category_data['ads_count'] = category.ads.where(deleted: false).count
        category_data
      end
    end
    render json: @categories
  end

  def analytics
    @category_analytics = Rails.cache.fetch('buyer_category_analytics', expires_in: 24.hours) do
      # Click-event based metrics (ad clicks, wishlist clicks, reveal clicks)
      click_rows = Category.joins(ads: :click_events)
                           .select("categories.id AS category_id, categories.name AS category_name, \
                                   SUM(CASE WHEN click_events.event_type = 'Ad-Click' THEN 1 ELSE 0 END) AS ad_clicks, \
                                   SUM(CASE WHEN click_events.event_type = 'Add-to-Wish-List' THEN 1 ELSE 0 END) AS wish_list_clicks, \
                                   SUM(CASE WHEN click_events.event_type = 'Reveal-Seller-Details' THEN 1 ELSE 0 END) AS reveal_clicks")
                           .group('categories.id, categories.name')

      click_by_category_id = click_rows.each_with_object({}) do |row, acc|
        acc[row.category_id] = row
      end

      # Real wishlist totals per category (based on WishList rows)
      wishlist_rows = Category.joins(ads: :wish_lists)
                              .select("categories.id AS category_id, categories.name AS category_name, COUNT(wish_lists.id) AS total_wishlists")
                              .group('categories.id, categories.name')

      wishlist_by_category_id = wishlist_rows.each_with_object({}) do |row, acc|
        acc[row.category_id] = row.total_wishlists.to_i
      end

      wishlist_name_by_category_id = wishlist_rows.each_with_object({}) do |row, acc|
        acc[row.category_id] = row.category_name
      end

      # Union of categories that appear in either clicks or wishlists
      all_category_ids = (click_by_category_id.keys + wishlist_by_category_id.keys).uniq

      all_category_ids.map do |category_id|
        click = click_by_category_id[category_id]
        {
          category_id: category_id,
          category_name: (click&.category_name || wishlist_name_by_category_id[category_id]),
          ad_clicks: click&.ad_clicks.to_i,
          wish_list_clicks: click&.wish_list_clicks.to_i,
          reveal_clicks: click&.reveal_clicks.to_i,
          total_wishlists: wishlist_by_category_id[category_id] || 0
        }
      end.sort_by { |h| h[:category_name].to_s }
    end
    render json: @category_analytics
  end
end
