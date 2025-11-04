class AddLastActiveAtToBuyers < ActiveRecord::Migration[7.1]
  def up
    unless column_exists?(:buyers, :last_active_at)
      add_column :buyers, :last_active_at, :datetime
    end
    
    # Set last_active_at to updated_at for existing buyers
    # This provides a reasonable default based on their last profile update
    execute <<-SQL
      UPDATE buyers 
      SET last_active_at = updated_at 
      WHERE last_active_at IS NULL
    SQL
  end

  def down
    remove_column :buyers, :last_active_at
  end
end
