class CreateWhatsappProductSessions < ActiveRecord::Migration[7.1]
  def change
    create_table :whatsapp_product_sessions, id: :uuid do |t|
      t.uuid :seller_id, null: false
      t.string :phone_number, null: false
      t.string :status, default: 'pending', null: false
      t.integer :step, default: 1, null: false
      t.text :product_data
      t.datetime :last_message_at

      t.timestamps
    end

    add_foreign_key :whatsapp_product_sessions, :sellers
    add_index :whatsapp_product_sessions, :phone_number
    add_index :whatsapp_product_sessions, :status
    add_index :whatsapp_product_sessions, [:seller_id, :status]
  end
end
