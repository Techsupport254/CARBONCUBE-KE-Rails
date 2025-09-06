class AddUniquenessConstraintsToSellers < ActiveRecord::Migration[8.0]
  def change
    # Add unique constraint for enterprise_name (shop name) - case insensitive
    add_index :sellers, 'LOWER(enterprise_name)', unique: true, name: 'index_sellers_on_lower_enterprise_name'
    
    # Add unique constraint for phone_number
    add_index :sellers, :phone_number, unique: true, name: 'index_sellers_on_phone_number'
    
    # Add unique constraint for business_registration_number (if present)
    add_index :sellers, :business_registration_number, unique: true, name: 'index_sellers_on_business_registration_number', where: 'business_registration_number IS NOT NULL AND business_registration_number != \'\''
    
    # Add unique constraint for username (if not already exists)
    add_index :sellers, :username, unique: true, name: 'index_sellers_on_username', where: 'username IS NOT NULL AND username != \'\''
  end
end
