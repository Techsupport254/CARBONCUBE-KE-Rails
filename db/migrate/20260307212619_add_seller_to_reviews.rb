class AddSellerToReviews < ActiveRecord::Migration[7.1]
  def change
    add_column :reviews, :seller_id, :string
    add_index :reviews, :seller_id
  end
end
