class CreateCallQueues < ActiveRecord::Migration[7.1]
  def change
    create_table :call_queues do |t|
      t.uuid :seller_id, null: false
      t.string :queue_type, null: false
      t.integer :priority, default: 0, null: false
      t.jsonb :metadata, default: {}
      t.string :status, default: 'pending', null: false
      t.datetime :resolved_at
      t.uuid :resolved_by

      t.timestamps
    end

    add_index :call_queues, :seller_id
    add_index :call_queues, :queue_type
    add_index :call_queues, :status
    add_index :call_queues, :priority
    add_index :call_queues, [:status, :priority]
    add_foreign_key :call_queues, :sellers
  end
end
