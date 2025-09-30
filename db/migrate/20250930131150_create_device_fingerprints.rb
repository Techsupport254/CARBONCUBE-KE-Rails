class CreateDeviceFingerprints < ActiveRecord::Migration[7.1]
  def change
    create_table :device_fingerprints do |t|
      t.string :device_id
      t.text :hardware_fingerprint
      t.text :user_agent
      t.datetime :last_seen

      t.timestamps
    end
    add_index :device_fingerprints, :device_id, unique: true
  end
end
