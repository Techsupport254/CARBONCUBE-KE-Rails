class AddLocationFieldsToInternalUsers < ActiveRecord::Migration[7.1]
  def change
    change_table :admins, bulk: true do |t|
      t.string :location
      t.string :city
      t.string :zipcode
      t.bigint :county_id
      t.bigint :sub_county_id
    end

    change_table :sales_users, bulk: true do |t|
      t.string :location
      t.string :city
      t.string :zipcode
      t.bigint :county_id
      t.bigint :sub_county_id
    end

    change_table :marketing_users, bulk: true do |t|
      t.string :location
      t.string :city
      t.string :zipcode
      t.bigint :county_id
      t.bigint :sub_county_id
    end
  end
end
