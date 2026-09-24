class AddSearchAndSyncIndexes < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    # Trigram indexes make ILIKE '%term%' and word_similarity() index-assisted
    # instead of full-table scans on every storefront search.
    add_index :ads, :title, using: :gin, opclass: :gin_trgm_ops,
              algorithm: :concurrently, name: 'index_ads_on_title_trgm'
    add_index :ads, :brand, using: :gin, opclass: :gin_trgm_ops,
              algorithm: :concurrently, name: 'index_ads_on_brand_trgm'
    add_index :sellers, :enterprise_name, using: :gin, opclass: :gin_trgm_ops,
              algorithm: :concurrently, name: 'index_sellers_on_enterprise_name_trgm'
    add_index :sellers, :fullname, using: :gin, opclass: :gin_trgm_ops,
              algorithm: :concurrently, name: 'index_sellers_on_fullname_trgm'

    # Delta-sync (last_sync_at) and price-range filters on hot listing queries.
    unless index_exists?(:ads, :updated_at)
      add_index :ads, :updated_at, algorithm: :concurrently,
                name: 'index_ads_on_updated_at'
    end
    unless index_exists?(:ads, :price)
      add_index :ads, :price, algorithm: :concurrently,
                name: 'index_ads_on_price'
    end

    # Seller#brand_kenya? and BrandKenyaController filter on status + seller_id.
    add_index :sales_brands, %i[status seller_id], algorithm: :concurrently,
              name: 'index_sales_brands_on_status_and_seller_id'
  end
end
