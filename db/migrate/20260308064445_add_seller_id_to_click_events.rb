class AddSellerIdToClickEvents < ActiveRecord::Migration[7.1]
  def change
    add_column :click_events, :seller_id, :uuid, if_not_exists: true
  end
end
