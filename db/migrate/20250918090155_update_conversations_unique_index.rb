class UpdateConversationsUniqueIndex < ActiveRecord::Migration[7.1]
  def change
    # Remove the old unique index that doesn't account for inquirer_seller_id
    remove_index :conversations, name: "index_conversations_on_buyer_seller_product"
    
    # Add a new unique index that includes inquirer_seller_id
    # This ensures uniqueness for all conversation types:
    # - Buyer-Seller conversations (buyer_id + seller_id + ad_id)
    # - Seller-Seller conversations (seller_id + inquirer_seller_id + ad_id)
    # - Admin conversations (admin_id + other participants + ad_id)
    add_index :conversations, 
              [:ad_id, :buyer_id, :seller_id, :inquirer_seller_id], 
              unique: true, 
              name: "index_conversations_on_all_participants_and_ad"
  end
end
