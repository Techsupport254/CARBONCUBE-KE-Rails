# frozen_string_literal: true

class ChangeSellerCarbonCodeAssignmentsSellerFkToCascade < ActiveRecord::Migration[7.1]
  def change
    remove_foreign_key :seller_carbon_code_assignments, :sellers
    add_foreign_key :seller_carbon_code_assignments, :sellers, on_delete: :cascade
  end
end
