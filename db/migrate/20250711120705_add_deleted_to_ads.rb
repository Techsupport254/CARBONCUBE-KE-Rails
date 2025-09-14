class AddDeletedToAds < ActiveRecord::Migration[7.1]
  def change
    add_column :ads, :deleted, :boolean, default: false
  end
end
