class AddWhatsappNotificationsToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :sellers, :whatsapp_notifications, :boolean, default: true, null: false
    add_column :buyers, :whatsapp_notifications, :boolean, default: true, null: false
  end
end
