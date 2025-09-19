class UpdateExistingSellersLastActiveAt < ActiveRecord::Migration[7.1]
  def up
    # Set last_active_at to updated_at for existing sellers
    # This provides a reasonable default based on their last profile update
    execute <<-SQL
      UPDATE sellers 
      SET last_active_at = updated_at 
      WHERE last_active_at IS NULL
    SQL
  end

  def down
    # No need to rollback this data migration
  end
end
