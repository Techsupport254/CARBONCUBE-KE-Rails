class CreateMobileReleases < ActiveRecord::Migration[7.1]
  def change
    create_table :mobile_releases do |t|
      t.string :version_name, null: false
      t.integer :version_code
      t.string :abi, null: false
      t.string :download_url, null: false
      t.boolean :is_stable, default: true
      t.boolean :active, default: true
      t.string :fingerprint

      t.timestamps
    end
    add_index :mobile_releases, [:version_name, :abi]
    add_index :mobile_releases, :active
  end
end
