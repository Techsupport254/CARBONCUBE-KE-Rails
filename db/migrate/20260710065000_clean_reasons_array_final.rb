class CleanReasonsArrayFinal < ActiveRecord::Migration[7.1]
  def up
    # Use the existing queue_type column to rebuild reasons array properly
    # This is the cleanest approach since queue_type still has the correct data
    
    execute <<-SQL
      UPDATE call_queues 
      SET reasons = JSON_BUILD_ARRAY(queue_type)
      WHERE queue_type IS NOT NULL
    SQL
  end
  
  def down
    # This migration is one-way
    raise ActiveRecord::IrreversibleMigration
  end
end
