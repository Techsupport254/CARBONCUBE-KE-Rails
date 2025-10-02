class AddOauthColumnsToSellers < ActiveRecord::Migration[7.1]
  def change
    add_column :sellers, :provider, :string
    add_column :sellers, :uid, :string
    add_column :sellers, :oauth_token, :string
    add_column :sellers, :oauth_refresh_token, :string
    add_column :sellers, :oauth_expires_at, :string
  end
end
