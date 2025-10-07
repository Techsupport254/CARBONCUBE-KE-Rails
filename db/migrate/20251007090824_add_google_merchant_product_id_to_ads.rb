class AddGoogleMerchantProductIdToAds < ActiveRecord::Migration[7.1]
  def change
    add_column :ads, :google_merchant_product_id, :string
  end
end
