class MakeSellerCarbonCodeAssignmentFieldsNullable < ActiveRecord::Migration[7.1]
  def change
    change_column_null :seller_carbon_code_assignments, :latitude, true
    change_column_null :seller_carbon_code_assignments, :longitude, true
    change_column_null :seller_carbon_code_assignments, :sales_user_id, true
  end
end
