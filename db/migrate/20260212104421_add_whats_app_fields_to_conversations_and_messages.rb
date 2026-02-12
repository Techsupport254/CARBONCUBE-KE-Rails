class AddWhatsAppFieldsToConversationsAndMessages < ActiveRecord::Migration[7.1]
  def change
    add_column :conversations, :is_whatsapp, :boolean, default: false
    add_index :conversations, :is_whatsapp
    
    add_column :messages, :whatsapp_message_id, :string
    add_index :messages, :whatsapp_message_id
  end
end

