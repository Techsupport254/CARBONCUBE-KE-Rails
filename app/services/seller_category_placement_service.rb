# app/services/seller_category_placement_service.rb
#
# Identifies the categories a seller belongs to - either because they picked
# them at signup (categories_sellers) or because they actually have ads
# posted there - and places the seller in the subcategory where they have
# the most active ads within each of those categories.
class SellerCategoryPlacementService
  def self.call(seller)
    new(seller).call
  end

  def initialize(seller)
    @seller = seller
  end

  def call
    return [] unless seller

    relevant_category_ids.map { |category_id| place_seller_in(category_id) }
  end

  private

  attr_reader :seller

  def relevant_category_ids
    (existing_category_ids | ad_category_ids)
  end

  def existing_category_ids
    seller.categories_seller_records.pluck(:category_id)
  end

  def ad_category_ids
    seller.ads.where(deleted: false).where.not(category_id: nil).distinct.pluck(:category_id)
  end

  def place_seller_in(category_id)
    membership = seller.categories_seller_records.find_or_initialize_by(category_id: category_id)
    membership.subcategory_id = top_subcategory_id(category_id)
    membership.save!
    membership
  end

  def top_subcategory_id(category_id)
    seller.ads
          .where(deleted: false, category_id: category_id)
          .where.not(subcategory_id: nil)
          .group(:subcategory_id)
          .order(Arel.sql('COUNT(*) DESC'))
          .limit(1)
          .count
          .keys
          .first
  end
end
