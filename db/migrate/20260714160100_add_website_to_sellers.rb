class AddWebsiteToSellers < ActiveRecord::Migration[7.1]
  def change
    add_column :sellers, :website, :string
  end
end
