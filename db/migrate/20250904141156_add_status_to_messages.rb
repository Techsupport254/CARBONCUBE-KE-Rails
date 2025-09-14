class AddStatusToMessages < ActiveRecord::Migration[7.1]
  def change
    add_column :messages, :status, :string
    add_column :messages, :read_at, :datetime
    add_column :messages, :delivered_at, :datetime
  end
end
