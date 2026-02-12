class CreateDeviceTokens < ActiveRecord::Migration[7.1]
  def change
    create_table :device_tokens do |t|
      t.references :user, polymorphic: true, null: false
      t.string :token
      t.string :platform

      t.timestamps
    end
    add_index :device_tokens, :token
  end
end
