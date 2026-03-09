class AddSellerToReviews < ActiveRecord::Migration[7.1]
  def change
    add_column :reviews, :seller_id, :string, if_not_exists: true
    add_index :reviews, :seller_id, if_not_exists: true
  end
end
