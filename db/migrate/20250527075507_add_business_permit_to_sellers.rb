class AddBusinessPermitToSellers < ActiveRecord::Migration[8.0]
  def change
    add_column :sellers, :business_permit, :string
  end
end
