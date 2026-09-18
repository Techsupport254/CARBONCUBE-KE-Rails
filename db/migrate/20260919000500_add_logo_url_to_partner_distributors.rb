# frozen_string_literal: true

class AddLogoUrlToPartnerDistributors < ActiveRecord::Migration[7.1]
  def change
    add_column :partner_distributors, :logo_url, :string
  end
end
