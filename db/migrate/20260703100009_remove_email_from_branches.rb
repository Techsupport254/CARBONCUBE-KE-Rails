class RemoveEmailFromBranches < ActiveRecord::Migration[7.1]
  def change
    remove_column :branches, :email, :string
  end
end
