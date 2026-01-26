class AddIsAddedBySalesToAds < ActiveRecord::Migration[7.1]
  def change
    add_column :ads, :is_added_by_sales, :boolean, null: true, default: nil
  end
end
