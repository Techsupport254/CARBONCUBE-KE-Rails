class CreateRiders < ActiveRecord::Migration[7.1]
  def change
    create_table :riders do |t|
      t.string :full_name
      t.string :phone_number
      t.references :age_group, null: false, foreign_key: true
      t.string :email
      t.string :id_number
      t.string :driving_license
      t.string :vehicle_type
      t.string :license_plate
      t.string :physical_address
      t.string :gender, default: 'Male'
      t.boolean :blocked, default: false
      t.string :password_digest
      t.string :kin_full_name
      t.string :kin_relationship
      t.string :kin_phone_number
      t.references :county, null: false, foreign_key: true
      t.references :sub_county, null: false, foreign_key: true

      t.timestamps
    end
  end
end
