class WishList < ApplicationRecord
  belongs_to :buyer, optional: true
  belongs_to :seller, optional: true
  belongs_to :ad

  # Ensure only one user type is associated
  validates :buyer_id, presence: true, unless: :seller_id?
  validates :seller_id, presence: true, unless: :buyer_id?

  after_commit :invalidate_category_caches

  private

  def invalidate_category_caches
    Rails.cache.delete('buyer_category_analytics')
    Rails.cache.delete('buyer_categories_with_ads_count')
  end
end
