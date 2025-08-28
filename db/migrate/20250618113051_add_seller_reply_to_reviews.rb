class AddSellerReplyToReviews < ActiveRecord::Migration[8.0]
  def change
    add_column :reviews, :seller_reply, :text
  end
end
