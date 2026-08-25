class CreateSellerCarbonCodeAssignments < ActiveRecord::Migration[7.1]
  def change
    # Tracks each time a sales user assigns a carbon code to a seller.
    # Captures the sales user's GPS location at the moment of assignment
    # so admins can verify the sales user was physically near the seller.
    create_table :seller_carbon_code_assignments, id: :uuid do |t|
      t.references :seller, foreign_key: true, type: :uuid, null: false
      t.references :carbon_code, foreign_key: true, type: :bigint, null: false
      t.references :sales_user, foreign_key: { to_table: :sales_users }, type: :uuid, null: false

      # Sales user's GPS location at time of assignment
      t.decimal :latitude, precision: 10, scale: 7, null: false
      t.decimal :longitude, precision: 10, scale: 7, null: false
      t.string :display_name
      t.string :area
      t.string :city
      t.string :county
      t.string :country

      # Distance (in km) between sales user's location and seller's registered location
      # Computed at assignment time for quick admin filtering
      t.decimal :distance_km, precision: 8, scale: 2

      t.text :notes

      t.timestamps
    end

    add_index :seller_carbon_code_assignments, :created_at
  end
end
