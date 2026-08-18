class AddLocationPrecisionToBranches < ActiveRecord::Migration[7.1]
  def change
    add_column :branches, :location_precision, :string, default: 'approximate'
    add_index :branches, :location_precision
  end
end
