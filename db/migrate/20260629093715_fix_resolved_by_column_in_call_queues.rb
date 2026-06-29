class FixResolvedByColumnInCallQueues < ActiveRecord::Migration[7.1]
  def change
    rename_column :call_queues, :resolved_by, :resolved_by_id
    add_foreign_key :call_queues, :sales_users, column: :resolved_by_id
  end
end
