class AddReasonsToCallQueue < ActiveRecord::Migration[7.1]
  def change
    add_column :call_queues, :reasons, :text, default: '[]', null: false
  end
end
