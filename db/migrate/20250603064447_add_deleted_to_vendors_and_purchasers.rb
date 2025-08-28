class AddDeletedToSellersAndBuyers < ActiveRecord::Migration[8.0]
  def change
    add_column :sellers, :deleted, :boolean, default: false, null: false
    add_column :buyers, :deleted, :boolean, default: false, null: false
  end
end
