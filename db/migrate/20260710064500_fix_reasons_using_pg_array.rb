class FixReasonsUsingPgArray < ActiveRecord::Migration[7.1]
  def up
    # Use PostgreSQL's string_to_array and array_to_json functions
    # to properly convert PostgreSQL array format to JSON
    
    execute <<-SQL
      UPDATE call_queues 
      SET reasons = array_to_json(string_to_array(reasons::text, ','))
      WHERE reasons::text LIKE '%,%'
    SQL
  end
  
  def down
    # This migration is one-way
    raise ActiveRecord::IrreversibleMigration
  end
end
