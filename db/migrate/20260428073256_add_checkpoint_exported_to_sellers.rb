class AddCheckpointExportedToSellers < ActiveRecord::Migration[7.1]
  def change
    add_column :sellers, :checkpoint_exported, :boolean, default: false
  end
end
