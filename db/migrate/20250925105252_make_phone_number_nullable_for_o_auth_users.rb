class MakePhoneNumberNullableForOAuthUsers < ActiveRecord::Migration[7.1]
  def change
    # Make phone_number nullable to support OAuth users who don't provide phone numbers
    change_column_null :buyers, :phone_number, true
    
    # Remove the unique constraint on phone_number since it can now be null
    # We'll add a partial unique index instead that only applies to non-null values
    remove_index :buyers, :phone_number if index_exists?(:buyers, :phone_number)
    add_index :buyers, :phone_number, unique: true, where: "phone_number IS NOT NULL"
  end
end
