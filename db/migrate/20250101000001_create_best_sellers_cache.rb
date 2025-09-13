class CreateBestSellersCache < ActiveRecord::Migration[7.1]
  def change
    create_table :best_sellers_caches do |t|
      t.string :cache_key, null: false, index: { unique: true }
      t.jsonb :data, null: false
      t.datetime :expires_at, null: false
      t.timestamps
    end
    
    add_index :best_sellers_caches, :expires_at
  end
end
