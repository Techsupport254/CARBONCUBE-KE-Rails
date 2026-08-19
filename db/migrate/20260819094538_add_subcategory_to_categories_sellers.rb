class AddSubcategoryToCategoriesSellers < ActiveRecord::Migration[7.1]
  def change
    add_reference :categories_sellers, :subcategory, type: :bigint, null: true, foreign_key: true, index: true
    add_index :categories_sellers, [:category_id, :subcategory_id], name: 'idx_categories_sellers_on_category_and_subcategory'
  end
end
