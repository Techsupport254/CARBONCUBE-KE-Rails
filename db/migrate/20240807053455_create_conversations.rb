class CreateConversations < ActiveRecord::Migration[8.0]
  def change
    create_table :conversations do |t|
      t.references :admin, foreign_key: { to_table: :admins }, null: true
      t.references :buyer, foreign_key: { to_table: :buyers }, null: true
      t.references :seller, foreign_key: { to_table: :sellers }, null: true
      t.references :ad, foreign_key: true, null: true  # Or :ad if you use that model name

      t.timestamps
    end

    # Optional: Enforce uniqueness of a conversation between buyer, seller, and ad
    add_index :conversations, [:buyer_id, :seller_id, :ad_id], unique: true, name: "index_conversations_on_buyer_seller_product"
  end
end
