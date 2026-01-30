class AddCarbonCodeIdToSellers < ActiveRecord::Migration[7.1]
  def change
    add_column :sellers, :carbon_code_id, :bigint
    add_index :sellers, :carbon_code_id
    add_foreign_key :sellers, :carbon_codes, column: :carbon_code_id
  end
end
