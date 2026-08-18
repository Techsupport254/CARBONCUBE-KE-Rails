class ChangeCallQueuesSellerFkToCascade < ActiveRecord::Migration[7.1]
  def change
    remove_foreign_key :call_queues, :sellers
    add_foreign_key :call_queues, :sellers, on_delete: :cascade
  end
end
