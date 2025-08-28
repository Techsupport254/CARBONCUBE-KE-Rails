class CreateWishLists < ActiveRecord::Migration[7.1]
  def change
    create_table :wish_lists do |t|
      t.references :buyer, null: false, foreign_key: true
      t.references :ad, null: false, foreign_key: true

      t.timestamps
    end
  end
end
