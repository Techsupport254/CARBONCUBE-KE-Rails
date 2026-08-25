class AddPingsToSalesUserFieldLocations < ActiveRecord::Migration[7.1]
  def change
    # JSONB array of hourly pings throughout the work day (8am-4pm).
    # Each entry: { ts: "2026-08-25T08:00:00+03:00", lat: -1.28, lng: 36.82, display_name: "...", ... }
    # Populated by SyncFieldLocationsJob when flushing from Redis to Postgres.
    add_column :sales_user_field_locations, :pings, :jsonb, default: []
    add_index :sales_user_field_locations, :pings, using: :gin
  end
end
