class CreateGoogleBusinessProfileConnections < ActiveRecord::Migration[7.1]
  def change
    create_table :google_business_profile_connections, id: :uuid do |t|
      t.references :seller, null: false, type: :uuid, foreign_key: true, index: { unique: true }
      t.string :google_account_id
      t.string :google_location_id
      t.string :location_name
      t.text :location_address
      t.string :access_token_ciphertext
      t.string :refresh_token_ciphertext
      t.datetime :access_token_expires_at
      t.string :status, null: false, default: 'connected'
      t.datetime :connected_at
      t.datetime :last_synced_at
      t.text :last_sync_error
      t.integer :review_count, null: false, default: 0
      t.decimal :average_rating, precision: 3, scale: 2

      t.timestamps
    end

    add_index :google_business_profile_connections, :status
    add_index :google_business_profile_connections,
              [:google_account_id, :google_location_id],
              unique: true,
              name: 'index_gbp_connections_on_google_location'
  end
end
