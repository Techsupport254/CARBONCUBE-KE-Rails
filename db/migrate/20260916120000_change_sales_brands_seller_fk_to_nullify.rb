# frozen_string_literal: true

class ChangeSalesBrandsSellerFkToNullify < ActiveRecord::Migration[7.1]
  def change
    remove_foreign_key :sales_brands, :sellers
    add_foreign_key :sales_brands, :sellers, on_delete: :nullify
  end
end
