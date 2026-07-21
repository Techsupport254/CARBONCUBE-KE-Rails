class AddSecondaryPhoneToBranches < ActiveRecord::Migration[7.1]
  def change
    add_column :branches, :secondary_phone, :string
  end
end
