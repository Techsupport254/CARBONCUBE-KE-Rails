class AddSecondaryPhoneNumberToBuyersAndSellers < ActiveRecord::Migration[7.1]
  def change
    add_column :buyers, :secondary_phone_number, :string, limit: 10
    add_column :sellers, :secondary_phone_number, :string, limit: 10
  end
end
