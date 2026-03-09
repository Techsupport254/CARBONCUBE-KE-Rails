class AddModelAndSpecificationsToAds < ActiveRecord::Migration[7.1]
  def change
    add_column :ads, :model, :string, if_not_exists: true
    add_column :ads, :specifications, :jsonb, if_not_exists: true
  end
end
