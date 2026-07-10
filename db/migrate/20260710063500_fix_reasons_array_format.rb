class FixReasonsArrayFormat < ActiveRecord::Migration[7.1]
  def up
    # Fix the reasons array format from PostgreSQL array notation to JSON
    # PostgreSQL uses {item1,item2} but we need ["item1","item2"]
    
    execute <<-SQL
      UPDATE call_queues 
      SET reasons = 
        '[' || 
        REPLACE(
          REPLACE(
            REPLACE(reasons::text, '{', ''),
            '}', ''
          ),
          ',',
          '","'
        ) || 
        ']'
      WHERE reasons::text LIKE '{%'
    SQL
  end
  
  def down
    # This migration is one-way
    raise ActiveRecord::IrreversibleMigration
  end
end
