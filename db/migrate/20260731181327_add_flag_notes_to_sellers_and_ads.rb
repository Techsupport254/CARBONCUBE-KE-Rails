class AddFlagNotesToSellersAndAds < ActiveRecord::Migration[7.1]
  def change
    add_column :sellers, :flag_notes, :text
    add_column :ads, :flag_notes, :text
  end
end
