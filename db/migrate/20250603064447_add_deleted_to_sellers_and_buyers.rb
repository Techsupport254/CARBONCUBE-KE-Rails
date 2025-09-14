class AddDeletedToSellersAndBuyers < ActiveRecord::Migration[7.1]
  def change
    add_column :sellers, :deleted, :boolean, default: false, null: false
    add_column :buyers, :deleted, :boolean, default: false, null: false
  end
end
