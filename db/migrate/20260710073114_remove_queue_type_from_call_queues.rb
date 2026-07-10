class RemoveQueueTypeFromCallQueues < ActiveRecord::Migration[7.1]
  def change
    remove_column :call_queues, :queue_type, :string
  end
end
