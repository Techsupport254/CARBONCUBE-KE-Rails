class AddFlaggedToSellers < ActiveRecord::Migration[7.1]
  def change
    add_column :sellers, :flagged, :boolean, default: false, null: false
  end
end
