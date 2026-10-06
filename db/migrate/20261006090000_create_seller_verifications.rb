class CreateSellerVerifications < ActiveRecord::Migration[7.1]
  def change
    create_table :seller_verifications, id: :uuid do |t|
      t.references :seller, type: :uuid, null: false, foreign_key: true
      t.references :sales_user, type: :uuid, null: false, foreign_key: true

      # verified | corrected | not_found | unreachable
      t.string :outcome, null: false, default: 'verified'

      # Checklist — which details the rep confirmed on-site
      t.boolean :location_confirmed, null: false, default: false
      t.boolean :phone_confirmed, null: false, default: false
      t.boolean :business_name_confirmed, null: false, default: false
      t.boolean :documents_confirmed, null: false, default: false

      # Audit trail of corrections applied live to the seller record:
      # { "location" => { "old" => "x", "new" => "y" }, ... }
      t.jsonb :corrections, null: false, default: {}

      t.text :notes

      # Rep's GPS at the time of verification
      t.decimal :latitude, precision: 10, scale: 6
      t.decimal :longitude, precision: 10, scale: 6
      t.string :display_name
      t.decimal :accuracy_m, precision: 8, scale: 2

      # Anti-fraud: rep GPS vs seller's geocoded branch, and vs the rep's own
      # hourly field pings for that day
      t.decimal :distance_to_shop_km, precision: 8, scale: 2
      t.decimal :nearest_ping_distance_km, precision: 8, scale: 2
      t.datetime :nearest_ping_at
      # verified | suspicious | pending
      t.string :gps_verdict, null: false, default: 'pending'

      t.timestamps
    end

    add_index :seller_verifications, :created_at
    add_index :seller_verifications, :outcome

    add_column :sellers, :field_verified_at, :datetime
  end
end
