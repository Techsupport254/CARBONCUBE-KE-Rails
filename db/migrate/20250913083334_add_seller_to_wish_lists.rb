class AddSellerToWishLists < ActiveRecord::Migration[7.1]
  def change
    # Make buyer reference optional
    change_column_null :wish_lists, :buyer_id, true

    # Add seller reference as optional
    add_reference :wish_lists, :seller, null: true, foreign_key: true

    # Add a check constraint to ensure either buyer_id or seller_id is present
    add_check_constraint :wish_lists,
                         "(buyer_id IS NOT NULL) OR (seller_id IS NOT NULL)",
                         name: "wish_lists_user_check"
  end
end
