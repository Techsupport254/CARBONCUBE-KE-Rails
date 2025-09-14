class AddBusinessPermitToSellers < ActiveRecord::Migration[7.1]
  def change
    add_column :sellers, :business_permit, :string
  end
end
