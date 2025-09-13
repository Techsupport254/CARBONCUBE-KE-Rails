class AddInquirerSellerToConversations < ActiveRecord::Migration[8.0]
  def change
    add_column :conversations, :inquirer_seller_id, :integer
    add_foreign_key :conversations, :sellers, column: :inquirer_seller_id
    add_index :conversations, :inquirer_seller_id
  end
end
