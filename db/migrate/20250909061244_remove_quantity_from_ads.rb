class RemoveQuantityFromAds < ActiveRecord::Migration[8.0]
  def change
    remove_column :ads, :quantity, :integer
  end
end
