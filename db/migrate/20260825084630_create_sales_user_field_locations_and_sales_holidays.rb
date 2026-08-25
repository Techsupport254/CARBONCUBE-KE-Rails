class CreateSalesUserFieldLocationsAndSalesHolidays < ActiveRecord::Migration[7.1]
  def change
    # Holidays that exempt sales users from field location check-ins
    create_table :sales_holidays do |t|
      t.string :name, null: false
      t.date :date, null: false
      t.boolean :recurring, default: false, null: false
      t.text :notes

      t.timestamps
    end

    add_index :sales_holidays, :date
    add_index :sales_holidays, :recurring

    # Daily field location check-ins from sales users
    create_table :sales_user_field_locations do |t|
      t.references :sales_user, null: false, foreign_key: true, type: :uuid
      t.decimal :latitude, precision: 10, scale: 8, null: false
      t.decimal :longitude, precision: 11, scale: 8, null: false
      t.string :display_name
      t.jsonb :address, default: {}
      t.string :area
      t.string :city
      t.string :county
      t.string :country
      t.text :notes
      t.date :check_in_date, null: false

      t.timestamps
    end

    add_index :sales_user_field_locations, [:sales_user_id, :check_in_date], unique: true, name: 'idx_sales_field_locations_user_date'
    add_index :sales_user_field_locations, :check_in_date
  end
end
