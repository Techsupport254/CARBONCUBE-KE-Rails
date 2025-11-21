class AllowNullCountyForOAuthSellers < ActiveRecord::Migration[7.1]
  def up
    # Change county_id and sub_county_id to allow NULL for OAuth users
    # This allows OAuth users to complete their profile later via the modal
    change_column_null :sellers, :county_id, true
    change_column_null :sellers, :sub_county_id, true
  end

  def down
    # Revert: Set NOT NULL constraint back
    # First, set default values for any NULL values
    execute <<-SQL
      UPDATE sellers 
      SET county_id = (SELECT id FROM counties WHERE name = 'Nairobi' LIMIT 1)
      WHERE county_id IS NULL;
      
      UPDATE sellers 
      SET sub_county_id = (SELECT id FROM sub_counties WHERE name LIKE '%Nairobi%' LIMIT 1)
      WHERE sub_county_id IS NULL;
    SQL
    
    change_column_null :sellers, :county_id, false
    change_column_null :sellers, :sub_county_id, false
  end
end
