class AddCountyToBranches < ActiveRecord::Migration[7.1]
  def change
    add_column :branches, :county_id, :bigint
    add_column :branches, :sub_county_id, :bigint
  end
end
