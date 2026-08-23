class AddProfileFieldsToInternalUsers < ActiveRecord::Migration[7.1]
  def change
    change_table :admins, bulk: true do |t|
      t.string :phone_number
      t.string :profile_picture
    end

    change_table :sales_users, bulk: true do |t|
      t.string :phone_number
      t.string :profile_picture
    end

    change_table :marketing_users, bulk: true do |t|
      t.string :phone_number
      t.string :profile_picture
    end
  end
end
