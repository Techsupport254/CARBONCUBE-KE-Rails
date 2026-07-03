class AddBranchIdToAds < ActiveRecord::Migration[7.1]
  def change
    add_column :ads, :branch_id, :uuid
    add_foreign_key :ads, :branches, column: :branch_id
    add_index :ads, :branch_id
  end
end
