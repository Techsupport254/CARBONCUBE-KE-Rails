class AddImageUrlToSubcategories < ActiveRecord::Migration[7.1]
  def change
    add_column :subcategories, :image_url, :text
  end
end
