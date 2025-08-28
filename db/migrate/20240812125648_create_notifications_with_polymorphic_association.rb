class CreateNotificationsWithPolymorphicAssociation < ActiveRecord::Migration[7.1]
  def change
    create_table :notifications do |t|
      t.references :notifiable, polymorphic: true, index: true
      t.integer :order_id
      t.string :status
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false

    end
  end
end
