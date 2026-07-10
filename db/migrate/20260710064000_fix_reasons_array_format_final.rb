class FixReasonsArrayFormatFinal < ActiveRecord::Migration[7.1]
  def up
    # Fix the reasons array format - properly convert PostgreSQL array to JSON
    # Current: [inactive_seller\",\"no_ads_uploaded]
    # Target: ["inactive_seller","no_ads_uploaded"]
    
    execute <<-SQL
      UPDATE call_queues 
      SET reasons = 
        '[' || 
        REPLACE(
          REPLACE(
            REPLACE(
              REPLACE(reasons::text, '[', ''),
              ']',
              ''
            ),
            '\"',
            ''
          ),
          ',',
          '","'
        ) || 
        ']'
      WHERE reasons::text LIKE '%,%'
    SQL
  end
  
  def down
    # This migration is one-way
    raise ActiveRecord::IrreversibleMigration
  end
end
