class AddProfilePictureToBranches < ActiveRecord::Migration[7.1]
  def change
    add_column :branches, :profile_picture, :string
  end
end
