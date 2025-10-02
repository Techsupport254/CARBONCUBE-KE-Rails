class SeedIssueEnumsAndData < ActiveRecord::Migration[7.1]
  def up
    # Update existing issues to use proper string values instead of numeric
    # Map numeric values to proper string enums
    
    # Status mapping: 0 = pending, 1 = in_progress, etc.
    execute <<-SQL
      UPDATE issues 
      SET status = CASE 
        WHEN status = '0' THEN 'pending'
        WHEN status = '1' THEN 'in_progress' 
        WHEN status = '2' THEN 'completed'
        WHEN status = '3' THEN 'closed'
        WHEN status = '4' THEN 'rejected'
        WHEN status = '5' THEN 'urgent'
        ELSE 'pending'
      END
      WHERE status IN ('0', '1', '2', '3', '4', '5');
    SQL

    # Priority mapping: 0 = low, 1 = medium, 2 = high, 3 = urgent
    execute <<-SQL
      UPDATE issues 
      SET priority = CASE 
        WHEN priority = '0' THEN 'low'
        WHEN priority = '1' THEN 'medium'
        WHEN priority = '2' THEN 'high'
        WHEN priority = '3' THEN 'urgent'
        ELSE 'medium'
      END
      WHERE priority IN ('0', '1', '2', '3');
    SQL

    # Category mapping: 0 = bug, 1 = feature_request, 2 = improvement, etc.
    execute <<-SQL
      UPDATE issues 
      SET category = CASE 
        WHEN category = '0' THEN 'bug'
        WHEN category = '1' THEN 'feature_request'
        WHEN category = '2' THEN 'improvement'
        WHEN category = '3' THEN 'security'
        WHEN category = '4' THEN 'performance'
        WHEN category = '5' THEN 'ui_ux'
        WHEN category = '6' THEN 'other'
        ELSE 'other'
      END
      WHERE category IN ('0', '1', '2', '3', '4', '5', '6');
    SQL

    # Set default values for any NULL values
    execute <<-SQL
      UPDATE issues 
      SET status = 'pending' 
      WHERE status IS NULL;
    SQL

    execute <<-SQL
      UPDATE issues 
      SET priority = 'medium' 
      WHERE priority IS NULL;
    SQL

    execute <<-SQL
      UPDATE issues 
      SET category = 'other' 
      WHERE category IS NULL;
    SQL
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
