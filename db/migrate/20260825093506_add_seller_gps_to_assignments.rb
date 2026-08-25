class AddSellerGpsToAssignments < ActiveRecord::Migration[7.1]
  def change
    # The seller's GPS at the moment they self-registered with a carbon code.
    # Captured from the seller's own phone. Used to cross-reference with the
    # sales user's hourly ping trail to verify the sales user was actually
    # in the field near the seller.
    add_column :seller_carbon_code_assignments, :seller_gps_latitude, :decimal, precision: 10, scale: 7
    add_column :seller_carbon_code_assignments, :seller_gps_longitude, :decimal, precision: 10, scale: 7
    add_column :seller_carbon_code_assignments, :seller_gps_display_name, :string

    # The sales user's nearest ping to the seller's registration GPS (computed server-side)
    add_column :seller_carbon_code_assignments, :nearest_ping_distance_km, :decimal, precision: 8, scale: 2
    add_column :seller_carbon_code_assignments, :nearest_ping_at, :datetime
  end
end
