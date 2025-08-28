class AddDeletedToAds < ActiveRecord::Migration[8.0]
  def change
    add_column :ads, :deleted, :boolean, default: false
  end
end
