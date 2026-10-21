class AddPremisesTypeToSellersAndVerifications < ActiveRecord::Migration[7.1]
  def change
    add_column :sellers, :premises_type, :string
    add_column :seller_verifications, :premises_type, :string
  end
end
