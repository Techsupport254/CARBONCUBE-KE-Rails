class AddPgSearchIndexesToAds < ActiveRecord::Migration[7.1]
  def change
    enable_extension :pg_trgm

    add_index :ads, :title, using: :gin, opclass: :gin_trgm_ops
    add_index :ads, :description, using: :gin, opclass: :gin_trgm_ops
  end
end
