class AddSellerIdIndexToSellerTiers < ActiveRecord::Migration[8.0]
  def change
    add_index :seller_tiers, :seller_id, name: 'index_seller_tiers_on_seller_id' unless index_exists?(:seller_tiers, :seller_id, name: 'index_seller_tiers_on_seller_id')
  end
end
