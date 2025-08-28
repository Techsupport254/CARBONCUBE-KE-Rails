class CreateBuyers < ActiveRecord::Migration[7.1]
  def change
    create_table :buyers do |t|
      t.string :fullname, null: false
      t.string :username, null: false
      t.string :password_digest
      t.string :email, null: false
      t.string :phone_number, limit: 10, null: false
      t.references :age_group, null: false, foreign_key: true
      t.string :zipcode
      t.string :city, null: false
      t.string :gender, null: false, default: 'Male'
      t.string :location
      t.string :profile_picture
      t.boolean :blocked, default: false

      # Optional references
      t.references :county, null: true, foreign_key: true
      t.references :sub_county, null: true, foreign_key: true
      t.references :income, foreign_key: true, null: true
      t.references :employment, foreign_key: true, null: true
      t.references :education, foreign_key: true, null: true
      t.references :sector, foreign_key: true, null: true

      t.timestamps
    end

    add_index :buyers, :username
    add_index :buyers, :email
  end
end
