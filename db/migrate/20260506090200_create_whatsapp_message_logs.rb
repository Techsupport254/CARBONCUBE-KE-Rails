class CreateWhatsappMessageLogs < ActiveRecord::Migration[7.1]
  def change
    create_table :whatsapp_message_logs, id: :uuid do |t|
      t.uuid :seller_id, null: false
      t.string :phone_number, null: false
      t.string :template_name, null: false
      t.string :message_id
      t.boolean :sent_successfully, default: false
      t.text :error_message
      t.timestamp :sent_at
      
      t.timestamps
    end
    
    add_foreign_key :whatsapp_message_logs, :sellers, column: :seller_id
    add_index :whatsapp_message_logs, [:seller_id, :template_name], unique: true
    add_index :whatsapp_message_logs, :phone_number
    add_index :whatsapp_message_logs, :sent_at
  end
end
