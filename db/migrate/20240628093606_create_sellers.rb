class CreateSellers < ActiveRecord::Migration[7.1]
  def change
    create_table :sellers do |t|
      t.string :fullname
      t.string :username
      t.string :description
      t.string :phone_number, limit: 10
      t.string :location
      t.string :business_registration_number
      t.string :enterprise_name
      t.references :county, null: false, foreign_key: true
      t.references :sub_county, null: false, foreign_key: true
      t.string :email
      t.string :profile_picture
      t.references :age_group, null: false, foreign_key: true
      t.string :zipcode
      t.string :city
      t.string :gender, default: 'Male'
      t.boolean :blocked, default: false
      t.string :password_digest
      
      t.timestamps
    end
  end
end
