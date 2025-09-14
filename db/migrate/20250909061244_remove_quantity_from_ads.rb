class RemoveQuantityFromAds < ActiveRecord::Migration[7.1]
  def change
    remove_column :ads, :quantity, :integer
  end
end
