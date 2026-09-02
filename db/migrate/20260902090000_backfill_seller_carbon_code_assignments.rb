# frozen_string_literal: true

class BackfillSellerCarbonCodeAssignments < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def up
    Seller.where.not(carbon_code_id: nil).includes(:carbon_code).find_each do |seller|
      carbon_code = seller.carbon_code
      next unless carbon_code

      # Check if assignment already exists
      existing = SellerCarbonCodeAssignment.find_by(seller_id: seller.id, carbon_code_id: carbon_code.id)
      next if existing

      sales_user = carbon_code.associable if carbon_code.associable_type == 'SalesUser'

      SellerCarbonCodeAssignment.create!(
        seller: seller,
        carbon_code: carbon_code,
        sales_user: sales_user,
        created_at: seller.created_at,
        updated_at: seller.updated_at
      )
    end
  end

  def down
    # No-op: backfilled records are preserved
  end
end
