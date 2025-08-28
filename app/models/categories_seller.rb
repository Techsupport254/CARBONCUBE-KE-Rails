class CategoriesSeller < ApplicationRecord
  self.table_name = 'categories_sellers' # Explicitly set the table name
  belongs_to :seller
  belongs_to :category
end
