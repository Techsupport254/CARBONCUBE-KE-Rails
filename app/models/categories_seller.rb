class CategoriesSeller < ApplicationRecord
  self.table_name = 'categories_sellers' # Explicitly set the table name
  self.primary_key = [:category_id, :seller_id]
  belongs_to :seller
  belongs_to :category
  belongs_to :subcategory, optional: true
end
