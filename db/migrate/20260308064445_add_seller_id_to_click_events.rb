class AddSellerIdToClickEvents < ActiveRecord::Migration[7.1]
  def change
    add_column :click_events, :seller_id, :uuid
  end
end
