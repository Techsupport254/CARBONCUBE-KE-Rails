class ChangePolymorphicIdsToUuidInNotificationsAndDeviceTokens < ActiveRecord::Migration[7.1]
  def up
    # Clear tables since we are changing column types and removing the old ID columns.
    # Existing rows would violate the NOT NULL constraint on the new columns.
    execute "DELETE FROM device_tokens"
    execute "DELETE FROM notifications"

    # DeviceTokens
    remove_column :device_tokens, :user_id
    add_column :device_tokens, :user_id, :uuid, null: false
    add_index :device_tokens, [:user_type, :user_id], name: 'index_device_tokens_on_user'
    
    # Notifications
    remove_column :notifications, :recipient_id
    add_column :notifications, :recipient_id, :uuid, null: false
    add_index :notifications, [:recipient_type, :recipient_id], name: 'index_notifications_on_recipient'
    
    remove_column :notifications, :notifiable_id
    add_column :notifications, :notifiable_id, :uuid
    add_index :notifications, [:notifiable_type, :notifiable_id], name: 'index_notifications_on_notifiable'
  end

  def down
    # Notifications
    remove_index :notifications, name: 'index_notifications_on_notifiable'
    remove_column :notifications, :notifiable_id
    add_column :notifications, :notifiable_id, :bigint
    add_index :notifications, [:notifiable_type, :notifiable_id], name: 'index_notifications_on_notifiable'

    remove_index :notifications, name: 'index_notifications_on_recipient'
    remove_column :notifications, :recipient_id
    add_column :notifications, :recipient_id, :bigint
    add_index :notifications, [:recipient_type, :recipient_id], name: 'index_notifications_on_recipient'

    # DeviceTokens
    remove_index :device_tokens, name: 'index_device_tokens_on_user'
    remove_column :device_tokens, :user_id
    add_column :device_tokens, :user_id, :bigint
    add_index :device_tokens, [:user_type, :user_id], name: 'index_device_tokens_on_user'
  end
end
