class WishList < ApplicationRecord
  belongs_to :buyer
  belongs_to :ad

  after_commit :invalidate_category_caches

  private

  def invalidate_category_caches
    Rails.cache.delete('buyer_category_analytics')
    Rails.cache.delete('buyer_categories_with_ads_count')
  end
end
