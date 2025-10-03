class SeedIssueEnumsAndData < ActiveRecord::Migration[7.1]
  def up
    # Skip data migration since issues table is empty
    # This migration was designed for existing data conversion
    puts "Skipping data migration - no existing issues to convert"
  end

  def down
    # Revert to numeric values if needed
    execute <<-SQL
      UPDATE issues 
      SET status = CASE 
        WHEN status = 'pending' THEN '0'
        WHEN status = 'in_progress' THEN '1'
        WHEN status = 'completed' THEN '2'
        WHEN status = 'closed' THEN '3'
        WHEN status = 'rejected' THEN '4'
        WHEN status = 'urgent' THEN '5'
        ELSE '0'
      END;
    SQL

    execute <<-SQL
      UPDATE issues 
      SET priority = CASE 
        WHEN priority = 'low' THEN '0'
        WHEN priority = 'medium' THEN '1'
        WHEN priority = 'high' THEN '2'
        WHEN priority = 'urgent' THEN '3'
        ELSE '1'
      END;
    SQL

    execute <<-SQL
      UPDATE issues 
      SET category = CASE 
        WHEN category = 'bug' THEN '0'
        WHEN category = 'feature_request' THEN '1'
        WHEN category = 'improvement' THEN '2'
        WHEN category = 'security' THEN '3'
        WHEN category = 'performance' THEN '4'
        WHEN category = 'ui_ux' THEN '5'
        WHEN category = 'other' THEN '6'
        ELSE '6'
      END;
    SQL
  end
end
