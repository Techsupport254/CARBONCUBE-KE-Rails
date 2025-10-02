class AddOauthColumnsToRiders < ActiveRecord::Migration[7.1]
  def change
    add_column :riders, :provider, :string
    add_column :riders, :uid, :string
    add_column :riders, :oauth_token, :string
    add_column :riders, :oauth_refresh_token, :string
    add_column :riders, :oauth_expires_at, :string
  end
end
