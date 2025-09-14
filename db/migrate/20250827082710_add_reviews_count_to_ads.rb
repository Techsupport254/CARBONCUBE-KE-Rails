class AddReviewsCountToAds < ActiveRecord::Migration[7.1]
  def change
    add_column :ads, :reviews_count, :integer, default: 0, null: false
    add_index :ads, :reviews_count
  end
end
