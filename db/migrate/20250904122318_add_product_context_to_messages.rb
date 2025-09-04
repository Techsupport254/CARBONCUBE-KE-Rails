class AddProductContextToMessages < ActiveRecord::Migration[8.0]
  def change
    # Add product context to individual messages
    add_column :messages, :ad_id, :integer
    add_column :messages, :product_context, :text
    
    # Add index for better performance
    add_index :messages, :ad_id
    
    # Add foreign key constraint
    add_foreign_key :messages, :ads, column: :ad_id, on_delete: :nullify
  end
end
