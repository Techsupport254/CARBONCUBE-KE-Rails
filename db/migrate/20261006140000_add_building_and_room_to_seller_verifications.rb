class AddBuildingAndRoomToSellerVerifications < ActiveRecord::Migration[7.1]
  def change
    change_table :seller_verifications, bulk: true do |t|
      t.string :building
      t.string :room
    end
  end
end
