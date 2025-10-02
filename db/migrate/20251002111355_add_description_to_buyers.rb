class AddDescriptionToBuyers < ActiveRecord::Migration[7.1]
  def change
    add_column :buyers, :description, :text
  end
end
