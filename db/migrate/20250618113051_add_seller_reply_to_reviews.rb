class AddSellerReplyToReviews < ActiveRecord::Migration[7.1]
  def change
    add_column :reviews, :seller_reply, :text
  end
end
