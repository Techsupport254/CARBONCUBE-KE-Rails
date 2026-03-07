class AddModelAndSpecificationsToAds < ActiveRecord::Migration[7.1]
  def change
    add_column :ads, :model, :string
    add_column :ads, :specifications, :jsonb
  end
end
