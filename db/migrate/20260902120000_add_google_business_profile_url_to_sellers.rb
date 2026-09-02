class AddGoogleBusinessProfileUrlToSellers < ActiveRecord::Migration[7.1]
  def change
    add_column :sellers, :google_business_profile_url, :string
  end
end
