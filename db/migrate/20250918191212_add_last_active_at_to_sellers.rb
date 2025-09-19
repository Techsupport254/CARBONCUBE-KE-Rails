class AddLastActiveAtToSellers < ActiveRecord::Migration[7.1]
  def change
    add_column :sellers, :last_active_at, :datetime
  end
end
