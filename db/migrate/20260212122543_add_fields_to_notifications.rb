class AddFieldsToNotifications < ActiveRecord::Migration[7.1]
  def change
    add_reference :notifications, :recipient, polymorphic: true, null: false
    add_column :notifications, :title, :string
    add_column :notifications, :body, :text
    add_column :notifications, :data, :json
    add_column :notifications, :read_at, :datetime
  end
end
