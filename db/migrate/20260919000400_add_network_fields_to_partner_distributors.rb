# frozen_string_literal: true

class AddNetworkFieldsToPartnerDistributors < ActiveRecord::Migration[7.1]
  def change
    change_table :partner_distributors, bulk: true do |t|
      t.string :territory
      t.string :business_type
      t.string :website
    end
  end
end
